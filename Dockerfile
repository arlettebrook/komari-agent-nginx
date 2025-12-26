# ---- downloader: fetch komari-agent only ----
FROM alpine:3.20 AS downloader

ARG KOMARI_VERSION=1.1.40
ARG TARGETARCH

RUN apk add --no-cache curl
RUN set -eux; \
    curl -fsSL -o /komari-agent \
      "https://github.com/komari-monitor/komari-agent/releases/download/${KOMARI_VERSION}/komari-agent-linux-${TARGETARCH}"; \
    chmod +x /komari-agent

# ---- deps: install node deps ----
FROM node:20-alpine3.20 AS deps
WORKDIR /app

# 如果你有 package-lock.json，强烈建议一起 COPY 并用 npm ci
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# ---- runtime ----
FROM node:20-alpine3.20

WORKDIR /app

# tini 用来做正确的 pid1 / 信号转发
RUN apk add --no-cache tini

# app files
COPY index.js index.html package.json ./
COPY --from=deps /app/node_modules ./node_modules

# komari-agent
COPY --from=downloader /komari-agent /usr/local/bin/komari-agent

# entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV NODE_ENV=production
EXPOSE 7860
STOPSIGNAL SIGTERM

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
