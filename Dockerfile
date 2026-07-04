# syntax=docker/dockerfile:1

# ── Flutter web (static UI) ───────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS web-build

WORKDIR /src/flutter_app

COPY flutter_app/pubspec.yaml flutter_app/pubspec.lock ./
RUN flutter pub get

COPY flutter_app/ ./

ARG PUBLIC_ORIGIN=http://localhost
COPY docker/flutter.env.docker /tmp/flutter.env.docker
RUN sed "s|__PUBLIC_ORIGIN__|${PUBLIC_ORIGIN}|g" /tmp/flutter.env.docker > assets/.env \
    && flutter build web --release

# ── Node.js API ───────────────────────────────────────────────────────────────
FROM node:20-bookworm-slim AS api

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

COPY server/ ./
RUN npx prisma generate

COPY docker/api-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV NODE_ENV=production \
    PORT=5001 \
    HOST=0.0.0.0

EXPOSE 5001

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||5001)+'/api/health').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "server.js"]

# ── Nginx (Flutter web + reverse proxy to API) ────────────────────────────────
FROM nginx:1.27-alpine AS web

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/app-config.json /usr/share/nginx/html/app-config.json
COPY --from=web-build /src/flutter_app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
