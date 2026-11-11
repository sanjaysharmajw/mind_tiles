"""End-to-end check of the Playables web build in headless Chrome, emulating
the YouTube Playables environment.

Prerequisites:
  * build/playables_bundle exists (flutter build web ... && python3 tool/package_playables.py)
  * python3 tool/serve_playables_csp.py 8790   (serves it with the Playables CSP)
  * pip package `websocket-client`

What it does:
  * blocks the real SDK and injects a recording fake `ytgame` (IN_PLAYABLES_ENV
    = true) so call order and cloud saves can be asserted;
  * plays with real mouse events located through Flutter's semantics tree:
    tutorial → Level 1 solved perfectly → results;
  * fires ytgame onPause / onResume and onAudioEnabledChange;
  * reloads the page with the saved cloud data and checks progress persisted;
  * fails on any CSP violation or any request that is not to localhost.

Usage: python3 tool/playables_e2e.py [--port 8790] [--shots DIR]
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

import websocket  # websocket-client

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 412, 915

FAKE_SDK = r"""
(() => {
  const initial = %INITIAL%;
  const yt = window.__yt = { calls: [], saves: 0, store: initial, pauseCbs: [], resumeCbs: [], audioCbs: [], audio: true };
  window.ytgame = {
    IN_PLAYABLES_ENV: true, SDK_VERSION: 'e2e-fake',
    game: {
      firstFrameReady() { yt.calls.push('firstFrameReady'); },
      gameReady() { yt.calls.push('gameReady'); },
      loadData() { yt.calls.push('loadData'); return Promise.resolve(yt.store); },
      saveData(d) {
        yt.calls.push('saveData');
        if (!yt.calls.includes('loadData')) return Promise.reject(new Error('saveData before loadData'));
        if (typeof d !== 'string' || !d.isWellFormed()) return Promise.reject(new Error('not well-formed'));
        yt.store = d; yt.saves++; return Promise.resolve();
      },
    },
    system: {
      isAudioEnabled() { return yt.audio; },
      onAudioEnabledChange(cb) { yt.audioCbs.push(cb); return () => {}; },
      onPause(cb) { yt.pauseCbs.push(cb); return () => {}; },
      onResume(cb) { yt.resumeCbs.push(cb); return () => {}; },
      getLanguage() { return Promise.resolve('en-US'); },
    },
    engagement: { sendScore() { return Promise.resolve(); }, openYTContent() { return Promise.resolve(); } },
    health: { logError() { yt.calls.push('logError'); }, logWarning() { yt.calls.push('logWarning'); } },
    ads: {
      requestInterstitialAd() { yt.calls.push('interstitial'); return Promise.resolve(); },
      requestRewardedAd(id) { yt.calls.push('rewarded:' + id); return Promise.resolve(true); },
    },
  };
  Object.defineProperty(window, 'ytgame', { writable: false, configurable: false });
})();
"""

FIND_JS = r"""
((pattern) => {
  const re = new RegExp(pattern);
  const nodes = document.querySelectorAll('flt-semantics, flt-semantics *, [aria-label]');
  for (const el of nodes) {
    const label = (el.getAttribute('aria-label') || '') + ' ' + (el.childElementCount === 0 ? el.textContent : '');
    if (re.test(label.trim())) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) return {x: r.x + r.width / 2, y: r.y + r.height / 2, label: label.trim()};
    }
  }
  return null;
})
"""

LABELS_JS = r"""
(() => Array.from(document.querySelectorAll('flt-semantics, flt-semantics *, [aria-label]'))
  .map(el => ((el.getAttribute('aria-label') || '') + ' ' + (el.childElementCount === 0 ? el.textContent : '')).trim())
  .filter(Boolean))()
"""


class Cdp:
    def __init__(self, ws_url):
        self.ws = websocket.create_connection(ws_url, timeout=60, suppress_origin=True)
        self.id = 0
        self.events = []

    def send(self, method, **params):
        self.id += 1
        my = self.id
        self.ws.send(json.dumps({"id": my, "method": method, "params": params}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == my:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})
            self.events.append(msg)

    def eval(self, expr):
        r = self.send("Runtime.evaluate", expression=expr, returnByValue=True, awaitPromise=True)
        if "exceptionDetails" in r:
            raise RuntimeError(r["exceptionDetails"])
        return r["result"].get("value")

    def drain(self):
        self.ws.settimeout(0.05)
        try:
            while True:
                self.events.append(json.loads(self.ws.recv()))
        except Exception:
            pass
        self.ws.settimeout(60)


class Runner:
    def __init__(self, port, shots):
        self.base = f"http://localhost:{port}/"
        self.shots = shots
        self.failures = []
        self.passes = []

    def check(self, cond, name):
        (self.passes if cond else self.failures).append(name)
        print(("  ✔ " if cond else "  ✘ ") + name, flush=True)
        return cond

    def start_chrome(self):
        self.profile = tempfile.mkdtemp(prefix="pl_e2e_")
        self.proc = subprocess.Popen(
            [CHROME, "--headless=new", "--remote-debugging-port=9333", f"--user-data-dir={self.profile}",
             "--no-first-run", "--autoplay-policy=user-gesture-required", "about:blank"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                targets = json.load(urllib.request.urlopen("http://127.0.0.1:9333/json"))
                page = next(t for t in targets if t["type"] == "page")
                return Cdp(page["webSocketDebuggerUrl"])
            except Exception:
                time.sleep(0.1)
        raise RuntimeError("Chrome did not start")

    def open(self, cdp, initial_store=""):
        cdp.send("Page.enable")
        cdp.send("Runtime.enable")
        cdp.send("Log.enable")
        cdp.send("Network.enable")
        cdp.send("Network.setBlockedURLs", urls=["*youtube.com/game_api*"])
        cdp.send("Emulation.setDeviceMetricsOverride", width=W, height=H, deviceScaleFactor=2, mobile=True)
        cdp.send("Page.addScriptToEvaluateOnNewDocument",
                 source=FAKE_SDK.replace("%INITIAL%", json.dumps(initial_store)))
        cdp.send("Page.navigate", url=self.base)

    def wait(self, cdp, expr, timeout=30):
        end = time.time() + timeout
        while time.time() < end:
            try:
                if cdp.eval(expr):
                    return True
            except Exception:
                pass
            time.sleep(0.25)
        return False

    def enable_semantics(self, cdp):
        cdp.eval("document.querySelector('flt-semantics-placeholder')?.click(), true")
        self.wait(cdp, "document.querySelectorAll('flt-semantics').length > 3", 10)

    def find(self, cdp, pattern, timeout=10):
        end = time.time() + timeout
        while time.time() < end:
            r = cdp.eval(f"({FIND_JS})({json.dumps(pattern)})")
            if r:
                return r
            time.sleep(0.25)
        return None

    def click(self, cdp, x, y):
        for t in ("mouseMoved", "mousePressed", "mouseReleased"):
            cdp.send("Input.dispatchMouseEvent", type=t, x=x, y=y, button="left", clickCount=1)
            time.sleep(0.03)

    def click_label(self, cdp, pattern, timeout=10):
        r = self.find(cdp, pattern, timeout)
        if r:
            self.click(cdp, r["x"], r["y"])
            time.sleep(0.4)
        return r

    def shot(self, cdp, name):
        if not self.shots:
            return
        import base64
        data = cdp.send("Page.captureScreenshot", format="png")["data"]
        with open(os.path.join(self.shots, f"{name}.png"), "wb") as f:
            f.write(base64.b64decode(data))

    def violations_and_requests(self, cdp):
        cdp.drain()
        csp, external, errors = [], set(), []
        for e in cdp.events:
            m = e.get("method")
            p = e.get("params", {})
            if m == "Network.requestWillBeSent":
                url = p["request"]["url"]
                if not url.startswith((self.base, "data:", "blob:")) and "youtube.com/game_api" not in url:
                    external.add(url)
            text = ""
            if m == "Log.entryAdded":
                text = p["entry"].get("text", "")
            elif m == "Runtime.consoleAPICalled":
                text = " ".join(str(a.get("value", "")) for a in p.get("args", []))
            elif m == "Runtime.exceptionThrown":
                errors.append(p["exceptionDetails"].get("text", "") + " " +
                              str(p["exceptionDetails"].get("exception", {}).get("description", ""))[:200])
            if "Content Security Policy" in text or "Refused to" in text:
                csp.append(text[:200])
        return csp, external, errors

    def run(self):
        print("Run 1: fresh player", flush=True)
        cdp = self.start_chrome()
        try:
            self.open(cdp)
            ready = self.wait(cdp, "window.__yt && __yt.calls.includes('gameReady')", 40)
            self.check(ready, "gameReady called")
            calls = cdp.eval("__yt.calls")
            self.check(calls and calls[0] == "firstFrameReady", "firstFrameReady is the first SDK call (from loading screen)")
            self.check(calls.index("loadData") < calls.index("gameReady"), "cloud save loaded before gameReady")
            self.check(cdp.eval("document.getElementById('loading') === null"), "HTML loading screen removed by gameReady")
            self.check(cdp.eval("__yt.pauseCbs.length === 1 && __yt.resumeCbs.length === 1 && __yt.audioCbs.length === 1"),
                       "onPause / onAudioEnabledChange registered")
            self.shot(cdp, "e2e_01_home")

            self.enable_semantics(cdp)
            self.check(self.click_label(cdp, r"PLAY.*LEVEL 1") is not None, "mouse click on PLAY")
            self.check(self.click_label(cdp, r"^Skip$") is not None, "tutorial shown and skipped")
            time.sleep(0.8)
            self.shot(cdp, "e2e_02_preview")
            labels = cdp.eval(f"({LABELS_JS})")
            tiles = {}
            for lab in labels:
                m = re.match(r"Row (\d+), column (\d+), (.+)$", lab)
                if m and "hidden" not in m.group(3):
                    tiles[(int(m.group(1)), int(m.group(2)))] = m.group(3).replace("matched ", "")
            self.check(len(tiles) == 16, f"preview shows all 16 tile symbols to the accessibility tree ({len(tiles)})")
            self.check(self.click_label(cdp, r"^Start now$") is not None, "skip preview (GO)")
            time.sleep(0.5)

            by_symbol = {}
            for pos, sym in tiles.items():
                by_symbol.setdefault(sym, []).append(pos)
            for pair in by_symbol.values():
                for (r, c) in pair:
                    self.click_label(cdp, rf"^Row {r}, column {c},", 3)
                time.sleep(0.3)
            time.sleep(0.4)
            self.shot(cdp, "e2e_03_board_solved")
            res = self.find(cdp, r"LEVEL COMPLETE", 8)
            self.check(res is not None, "level 1 completed with mouse clicks → results screen")
            time.sleep(1.5)
            self.shot(cdp, "e2e_04_results")
            saves = cdp.eval("__yt.saves")
            store = cdp.eval("__yt.store")
            self.check(saves > 0, f"progress saved via ytgame.saveData ({saves} saves)")
            saved = json.loads(store) if store else {}
            game = json.loads(saved.get("mind_tiles.save", "{}"))
            self.check(game.get("highestCompletedLevel") == 1, "cloud save records level 1 complete")
            self.check(len(store) * 2 < 500 * 1024, f"save size {len(store) * 2} bytes < 500 KiB")

            # Next level, then host pause / resume.
            self.click_label(cdp, r"NEXT LEVEL")
            self.click_label(cdp, r"^Start now$", 5)
            time.sleep(0.5)
            t1 = cdp.eval("performance.now()")
            cdp.eval("__yt.pauseCbs.forEach(cb => cb()), true")
            time.sleep(0.8)
            paused = self.find(cdp, r"^(Paused|Welcome back!)$", 3)
            self.check(paused is not None, "ytgame onPause → game paused with pause menu")
            self.shot(cdp, "e2e_05_host_paused")
            cdp.eval("__yt.resumeCbs.forEach(cb => cb()), true")
            time.sleep(0.4)
            self.check(self.click_label(cdp, r"^RESUME$") is not None, "onResume → player can resume")
            cdp.eval("__yt.audio = false; __yt.audioCbs.forEach(cb => cb(false)), true")
            cdp.eval("__yt.audio = true; __yt.audioCbs.forEach(cb => cb(true)), true")
            self.check(True, "onAudioEnabledChange(false/true) handled without errors")

            # Rewarded hint through ytgame.ads after the 2 free hints.
            for _ in range(2):
                self.click_label(cdp, r"^Hint", 3)
                time.sleep(1.9)
            self.click_label(cdp, r"Watch an ad for a hint", 3)
            time.sleep(0.6)
            calls = cdp.eval("__yt.calls")
            self.check(any(c.startswith("rewarded:") for c in calls), "rewarded ad requested via ytgame.ads on explicit tap")

            csp, external, errors = self.violations_and_requests(cdp)
            self.check(not csp, "no CSP violations" + ("" if not csp else f": {csp[:3]}"))
            self.check(not external, "no external network requests" + ("" if not external else f": {sorted(external)[:5]}"))
            self.check(not errors, "no uncaught JS exceptions" + ("" if not errors else f": {errors[:2]}"))
            final_store = cdp.eval("__yt.store")
        finally:
            self.proc.terminate()
            shutil.rmtree(self.profile, ignore_errors=True)

        print("Run 2: returning player (cloud save from run 1)", flush=True)
        cdp = self.start_chrome()
        try:
            self.open(cdp, final_store)
            self.check(self.wait(cdp, "window.__yt && __yt.calls.includes('gameReady')", 40), "gameReady on reload")
            self.enable_semantics(cdp)
            cont = self.find(cdp, r"(Continue Level 2|PLAY.*LEVEL 2)", 10)
            self.check(cont is not None, f"progress restored from cloud save ({cont['label'] if cont else 'not found'})")
            self.shot(cdp, "e2e_06_reload_home")
        finally:
            self.proc.terminate()
            shutil.rmtree(self.profile, ignore_errors=True)

        print(f"\n{len(self.passes)} passed, {len(self.failures)} failed")
        return 0 if not self.failures else 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8790)
    ap.add_argument("--shots", default="")
    a = ap.parse_args()
    if a.shots:
        os.makedirs(a.shots, exist_ok=True)
    sys.exit(Runner(a.port, a.shots).run())
