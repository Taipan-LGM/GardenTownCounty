#!/bin/sh
# Start nginx on Render's $PORT. Avoid envsubst so $uri is never mangled.
set -eu

PORT="${PORT:-10000}"

cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen       0.0.0.0:${PORT};
    server_name  _;
    root         /usr/share/nginx/html;
    index        index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /assets/ {
        try_files \$uri =404;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location = /index.html {
        add_header Cache-Control "no-cache";
    }

    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache";
    }

    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
    gzip_min_length 256;
}
EOF

echo "==> nginx config (PORT=${PORT}):"
cat /etc/nginx/conf.d/default.conf

if [ ! -f /usr/share/nginx/html/index.html ]; then
  echo "==> ERROR: /usr/share/nginx/html/index.html missing"
  ls -la /usr/share/nginx/html || true
  exit 1
fi

echo "==> web root:"
ls -la /usr/share/nginx/html | head -n 30

nginx -t
echo "==> starting nginx on 0.0.0.0:${PORT}"
exec nginx -g 'daemon off;'
