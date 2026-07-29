# Garden Town County — Flutter web on Render (Docker).
# Build: Flutter 3.44 / Dart 3.12 (gmeligio flutter-web image).
# Serve: nginx on $PORT (Render injects PORT).

# ── Build ──────────────────────────────────────────────────────────────────
# Image runs as non-root `flutter` by default; COPY must use --chown or
# pub get fails with: Cannot open file 'pubspec.lock' (Permission denied).
FROM ghcr.io/gmeligio/flutter-web:3.44.8 AS build

WORKDIR /app

USER root
COPY --chown=flutter:flutter pubspec.yaml analysis_options.yaml ./
USER flutter
RUN flutter pub get

USER root
COPY --chown=flutter:flutter . .
USER flutter
# CACHEBUST forces a fresh web build on each version ship (avoid stale layers).
ARG CACHEBUST=1.18.16+79
RUN flutter pub get \
 && flutter build web --release --pwa-strategy=none \
 && printf '%s\n' "{\"version\":\"1.18.16\",\"build\":\"79\",\"label\":\"v1.18.16+79\"}" \
      > /app/build/web/version.json

# ── Serve ──────────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

RUN rm -f /etc/nginx/conf.d/default.conf

COPY --from=build /app/build/web /usr/share/nginx/html
COPY docker/start-nginx.sh /start-nginx.sh
RUN chmod +x /start-nginx.sh \
 && sed -i 's/\r$//' /start-nginx.sh

ENV PORT=10000
EXPOSE 10000

# Replace default entrypoint so Render env vars cannot break nginx templates
ENTRYPOINT ["/start-nginx.sh"]
