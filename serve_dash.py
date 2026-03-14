#!/usr/bin/env python3
"""
Very small HTTP server to host one of the DASH test directories.

It serves static files from either:
  - test_data/dash
  - test_data/dash_from_c

Controlled by the hardcoded SERVE_SUBDIR constant below.
"""

from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import mimetypes
import os

#ci trigger
# Change this to "dash" or "dash_from_c" to switch which set you serve.
SERVE_SUBDIR = "dash_mojo"        # or "dash_from_c"


class DashRequestHandler(SimpleHTTPRequestHandler):
    """Serve files from the chosen DASH directory with a better MIME type for .mpd."""

    # Root directory of the repo: one level up from this file.
    repo_root = Path(__file__).resolve().parent
    serve_root = repo_root / "test_data" / SERVE_SUBDIR

    def translate_path(self, path: str) -> str:
        # Strip leading slash and map to serve_root.
        rel = path.lstrip("/")
        # Default to the MPD when requesting root.
        if rel == "":
            # Try to find any .mpd in the directory.
            # mpds = list(self.serve_root.glob("*.mpd"))
            # if mpds:
            #     return str(mpds[0])
            # mpds = list(self.serve_root.glob("*.mp4"))
            # print(mpds)
            # if mpds:
            #     return str(mpds[0])
            return str(self.repo_root / "test.html")

        return str(self.serve_root / rel)

    def guess_type(self, path: str) -> str:
        # Ensure .mpd gets the right DASH MIME type.
        print('guess_type', path)
        if path.endswith(".mpd"):
            return "application/dash+xml"
        # elif path.endswith(".mp4"):
        #     return "video/mp4"
        # Let the default machinery handle everything else.
        base, ext = os.path.splitext(path)
        if ext in mimetypes.types_map:
            print('ext', ext)
            print('mimetypes.types_map[ext]', mimetypes.types_map[ext])
            return mimetypes.types_map[ext]
        return "application/octet-stream"

    def end_headers(self) -> None:
        # Allow requests from file:// and other origins (for local dash.js testing).
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Range, Origin, Accept, Content-Type")
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(200, "ok")
        self.end_headers()


def main() -> None:
    # Make sure to run: Cmd + Shift + R in the browser to clear cache.
    host = "127.0.0.1"
    port = 8000

    handler = DashRequestHandler
    httpd = HTTPServer((host, port), handler)

    print(f"Serving '{SERVE_SUBDIR}' from: {handler.serve_root}")
    print(f"URL:   http://{host}:{port}/")
    print("Press Ctrl+C to stop.")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()


