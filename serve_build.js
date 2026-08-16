const http = require('http');
const fs = require('fs');
const path = require('path');

const host = '127.0.0.1';
const port = Number(process.env.PORT || 3007);
const root = path.join(__dirname, 'build', 'web');

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.map': 'application/json; charset=utf-8'
};

const server = http.createServer((req, res) => {
  const requestUrl = new URL(req.url, `http://${req.headers.host || '127.0.0.1'}`);
  let pathname = decodeURIComponent(requestUrl.pathname);
  if (pathname === '/') pathname = '/index.html';

  const responseHeaders = {
    'Cache-Control': 'no-store, no-cache, must-revalidate',
    Pragma: 'no-cache',
    Expires: '0'
  };

  const fullPath = path.resolve(root, `.${pathname}`);
  if (!fullPath.startsWith(root)) {
    res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Forbidden');
    return;
  }

  fs.stat(fullPath, (err, stat) => {
    if (err || !stat.isFile()) {
      const fallback = path.join(root, 'index.html');
      fs.readFile(fallback, (readErr, data) => {
        if (readErr) {
          res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
          res.end('Not found');
          return;
        }
        res.writeHead(200, {
          ...responseHeaders,
          'Content-Type': mimeTypes['.html'] || 'text/html; charset=utf-8'
        });
        res.end(data);
      });
      return;
    }

    const ext = path.extname(fullPath).toLowerCase();
    const contentType = mimeTypes[ext] || 'application/octet-stream';
    fs.readFile(fullPath, (readErr, data) => {
      if (readErr) {
        res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('Server error');
        return;
      }
      res.writeHead(200, { ...responseHeaders, 'Content-Type': contentType });
      res.end(data);
    });
  });
});

server.listen(port, host, () => {
  console.log(`Serving ${root} at http://${host}:${port}`);
});
