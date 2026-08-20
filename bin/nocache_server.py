#!/usr/bin/env python3
"""Static file server for build/web with aggressive no-cache headers.
Use this to serve the Flutter web bundle during local UI testing so the
browser never serves a stale main.dart.js / assets.
"""
import http.server
import socketserver
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "web")
ROOT = os.path.abspath(ROOT)
PORT = 8085


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


class ReuseTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    with ReuseTCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"Serving {ROOT} on http://localhost:{PORT} (no-cache)")
        httpd.serve_forever()
