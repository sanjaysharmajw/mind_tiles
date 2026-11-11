"""Packages and validates the YouTube Playables web bundle.

Usage (from the project root):
    flutter build web -t lib/main_playables.dart --release --no-web-resources-cdn \
        -o "$PWD/build/playables"
    python3 tool/package_playables.py

It copies build/playables to build/playables_bundle without files the
JS/CanvasKit build never loads, checks the bundle against the Playables
certification limits, prints a report and writes build/mind_tiles_playables.zip.

Limits checked (https://developers.google.com/youtube/gaming/playables/certification/requirements_stability):
  * initial bundle  MUST < 30 MiB, SHOULD < 15 MiB  (HTTP-compressed bytes)
  * total bundle    MUST < 250 MiB
  * each file       MUST < 30 MiB, SHOULD < 512 KiB
  * file count      MUST <= 8000
  * file names      only [A-Za-z0-9_.-]
  * relative paths only; no external URLs except the YouTube SDK
Exit code 1 if any MUST fails.
"""

import gzip
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "build", "playables")
OUT = os.path.join(ROOT, "build", "playables_bundle")
ZIP = os.path.join(ROOT, "build", "mind_tiles_playables.zip")

MiB = 1024 * 1024
KiB = 1024

# Files the dart2js + CanvasKit build never requests.
PRUNE_DIRS = {
    "canvaskit/experimental_webparagraph",
}
PRUNE_PATTERNS = [
    re.compile(r"\.symbols$"),                 # debug symbol maps
    re.compile(r"^canvaskit/skwasm"),          # only for --wasm builds
    re.compile(r"^canvaskit/wimp"),            # only for --wasm builds
    re.compile(r"^\.last_build_id$"),
    re.compile(r"^flutter_service_worker\.js$"),
    re.compile(r"notifications_service_worker\.js$"),  # mobile-only plugin asset
]

# Loaded before gameReady (initial bundle). Chrome/Edge load the "chromium"
# CanvasKit variant; Safari/Firefox load the full one — report the worst case.
INITIAL_COMMON = [
    "index.html", "flutter_bootstrap.js", "main.dart.js",
    "assets/AssetManifest.bin.json", "assets/FontManifest.json",
    "assets/fonts/MaterialIcons-Regular.otf",
    "assets/assets/fonts/LilitaOne-Regular.ttf",
    "assets/assets/fonts/Roboto-Regular.ttf",
    "assets/assets/fonts/Roboto-Bold.ttf",
    "assets/assets/fonts/Roboto-Black.ttf",
]
INITIAL_VARIANTS = {
    "Chrome/Edge (chromium CanvasKit)": ["canvaskit/chromium/canvaskit.js", "canvaskit/chromium/canvaskit.wasm"],
    "Safari/Firefox (full CanvasKit)": ["canvaskit/canvaskit.js", "canvaskit/canvaskit.wasm"],
}
TEXT_EXT = (".html", ".js", ".json", ".css")
NAME_RE = re.compile(r"^[A-Za-z0-9_.\-]+$")
URL_RE = re.compile(rb"https?://[A-Za-z0-9.\-]+[^\s\"'`)<>]*")
ALLOWED_URL_PREFIXES = (b"https://www.youtube.com/game_api/",)


def rel_files(base):
    out = []
    for d, _, files in os.walk(base):
        for f in files:
            out.append(os.path.relpath(os.path.join(d, f), base).replace(os.sep, "/"))
    return sorted(out)


def gz(path):
    with open(path, "rb") as f:
        return len(gzip.compress(f.read(), 9))


def fmt(n):
    return f"{n / MiB:.2f} MiB" if n >= MiB else f"{n / KiB:.0f} KiB"


def main():
    if not os.path.isdir(SRC):
        sys.exit("build/playables not found — run the flutter build first")
    shutil.rmtree(OUT, ignore_errors=True)
    pruned = []
    for rel in rel_files(SRC):
        if any(rel.startswith(d + "/") for d in PRUNE_DIRS) or any(p.search(rel) for p in PRUNE_PATTERNS):
            pruned.append(rel)
            continue
        dst = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(SRC, rel), dst)

    files = rel_files(OUT)
    sizes = {f: os.path.getsize(os.path.join(OUT, f)) for f in files}
    total = sum(sizes.values())
    must_fail, should_warn = [], []

    print(f"Pruned {len(pruned)} files not used by the JS/CanvasKit build")
    print(f"Files: {len(files)}   total: {fmt(total)}")

    if len(files) > 8000:
        must_fail.append(f"file count {len(files)} > 8000")
    if total >= 250 * MiB:
        must_fail.append(f"total bundle {fmt(total)} >= 250 MiB")

    for f, s in sizes.items():
        if s >= 30 * MiB:
            must_fail.append(f"{f} is {fmt(s)} (>= 30 MiB)")
        elif s >= 512 * KiB:
            should_warn.append(f"{f} is {fmt(s)} raw / {fmt(gz(os.path.join(OUT, f)))} gzip (SHOULD < 512 KiB)")
        for part in f.split("/"):
            if not NAME_RE.match(part):
                must_fail.append(f"invalid characters in file name: {f}")

    # Absolute paths and external URLs in text files.
    for f in files:
        if not f.endswith(TEXT_EXT):
            continue
        data = open(os.path.join(OUT, f), "rb").read()
        if f == "index.html":
            if b"<base " in data:
                must_fail.append("index.html contains a <base> tag (paths must be relative)")
            for m in re.finditer(rb'(?:src|href)="(/[^"]*)"', data):
                must_fail.append(f"index.html uses absolute path {m.group(1).decode()}")
        urls = {m.group(0) for m in URL_RE.finditer(data)}
        hosts = sorted({u.split(b"/")[2].decode() for u in urls if not u.startswith(ALLOWED_URL_PREFIXES)})
        if hosts:
            should_warn.append(f"{f} mentions URLs on: {', '.join(hosts)} (verify none are fetched at runtime)")

    print("\nInitial bundle (loaded before gameReady, gzip as served over HTTP):")
    worst = 0
    for name, extra in INITIAL_VARIANTS.items():
        n = sum(gz(os.path.join(OUT, f)) for f in INITIAL_COMMON + extra if os.path.exists(os.path.join(OUT, f)))
        worst = max(worst, n)
        print(f"  {name:36s} {fmt(n)}")
    if worst >= 30 * MiB:
        must_fail.append(f"initial bundle {fmt(worst)} >= 30 MiB")
    elif worst >= 15 * MiB:
        should_warn.append(f"initial bundle {fmt(worst)} >= 15 MiB")

    print("\nMUST failures:" if must_fail else "\nMUST checks: all passed ✔")
    for m in must_fail:
        print("  ✘", m)
    if should_warn:
        print("SHOULD warnings:")
        for w in should_warn:
            print("  •", w)

    if os.path.exists(ZIP):
        os.remove(ZIP)
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(os.path.join(OUT, f), f)  # index.html at the zip root
    print(f"\nWrote {os.path.relpath(ZIP, ROOT)} ({fmt(os.path.getsize(ZIP))}) — entry point: index.html")
    sys.exit(1 if must_fail else 0)


if __name__ == "__main__":
    main()
