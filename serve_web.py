import os
import http.server
import socketserver
from pathlib import Path

ROOT = Path(__file__).resolve().parent / 'build' / 'web'

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    port = 3013
    with socketserver.TCPServer(('127.0.0.1', port), QuietHandler) as httpd:
        print(f'Serving {ROOT} on http://127.0.0.1:{port}')
        httpd.serve_forever()
