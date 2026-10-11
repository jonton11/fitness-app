# syntax=docker/dockerfile:1

FROM node:24-alpine AS web-build

WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM caddy:2.10-alpine

COPY deployment/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=web-build /web/dist /srv
