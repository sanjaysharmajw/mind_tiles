"""Serves build/playables_bundle locally with the YouTube Playables
Content-Security-Policy, so CSP violations (external calls, CDN fonts,
blocked scripts) show up exactly as they would on YouTube.

CSP string from https://developers.google.com/youtube/gaming/playables/reference/test_suite_guide

Usage:  python3 tool/serve_playables_csp.py [port]   →  http://localhost:8790/
Every requested path is logged to stdout.
"""

import functools
import gzip
import http.server
import os
import sys

CSP = (
    "default-src 'none'; "
    "script-src 'report-sample' 'self' 'unsafe-eval' 'unsafe-inline' blob: "
    "https://www.youtube.com/game_api/v0 https://www.youtube.com/game_api/v0/ "
    "https://www.youtube.com/game_api/v1 https://www.youtube.com/game_api/v1/; "
    "object-src 'none'; "
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
    "img-src 'self' blob: data:; "
    "media-src 'self' blob:; "
    "font-src 'self' data: https://fonts.googleapis.com https://fonts.gstatic.com; "
    "connect-src 'self' blob: data:; "
    "sandbox allow-pointer-lock allow-same-origin allow-scripts; "
    "base-uri 'self'; "
    "manifest-src 'self'; "
    "worker-src 'self' blob:"
)

ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "playables_bundle")
COMPRESSIBLE = (".js", ".wasm", ".html", ".json", ".ttf", ".otf", ".frag", "NOTICES")


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".m4a": "audio/mp4",
    }

    def end_headers(self):
        self.send_header("Content-Security-Policy", CSP)
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            path = os.path.join(path, "index.html")
        accepts_gzip = "gzip" in self.headers.get("Accept-Encoding", "")
        if os.path.isfile(path) and accepts_gzip and path.endswith(COMPRESSIBLE):
            # Mirror YouTube's HTTP compression.
            data = gzip.compress(open(path, "rb").read(), 6)
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(path))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            print("GET", self.path, flush=True)
            return
        print("GET", self.path, flush=True)
        super().do_GET()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8790
    handler = functools.partial(Handler, directory=ROOT)
    print(f"Serving {os.path.abspath(ROOT)} with Playables CSP on http://localhost:{port}/", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
