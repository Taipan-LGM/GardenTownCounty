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
RUN flutter pub get \
 && flutter build web --release --pwa-strategy=none

# ── Serve ──────────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Drop default site so only our templated config is active
RUN rm -f /etc/nginx/conf.d/default.conf

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

# Render provides PORT at runtime; default for local docker run
ENV PORT=10000
EXPOSE 10000

# Explicit start: substitute only PORT, then validate + run nginx
CMD ["/bin/sh", "-c", "envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -t && nginx -g 'daemon off;'"]
