# Garden Town County — Flutter web on Render (Docker).
# Build: latest Flutter 3.44 / Dart 3.12 compatible image.
# Serve: nginx on $PORT (Render injects PORT).

# ── Build ──────────────────────────────────────────────────────────────────
FROM ghcr.io/gmeligio/flutter-web:3.44.8 AS build

WORKDIR /app

# Warm pub cache with lockfile-friendly layer
COPY pubspec.yaml analysis_options.yaml ./
RUN flutter pub get

COPY . .
RUN flutter pub get \
 && flutter build web --release --pwa-strategy=none

# ── Serve ──────────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Official nginx image runs envsubst on /etc/nginx/templates/*.template
COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

ENV PORT=10000
EXPOSE 10000

# Default CMD from nginx image handles template → conf.d + nginx -g 'daemon off;'
