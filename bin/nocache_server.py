#!/usr/bin/env python3
"""Static file server for build/web with aggressive no-cache headers.

Use this to serve the Flutter web bundle during local UI testing so the
browser never serves a stale main.dart.js / assets.

Threaded + HTTP/1.0 (no keep-alive) so a single slow/hung client connection
can never block the whole server (the previous single-threaded build could
freeze on one stuck keep-alive socket).

Optional: pass --port N to listen on a different port.
"""
import http.server
import socketserver
import os
import argparse

ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "web")
ROOT = os.path.abspath(ROOT)
PORT = 8085


class Handler(http.server.SimpleHTTPRequestHandler):
    # HTTP/1.0 => no keep-alive, each request gets its own connection and the
    # thread is released immediately after the response. Prevents a hung client
    # from pinning a worker thread forever.
    protocol_version = "HTTP/1.0"

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


class ThreadingReuseTCPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()

    with ThreadingReuseTCPServer(("0.0.0.0", args.port), Handler) as httpd:
        print(f"Serving {ROOT} on http://localhost:{args.port} (no-cache, threaded)")
        httpd.serve_forever()
