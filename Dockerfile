# ---- downloader stage (only for fetching the agent binary) ----
FROM alpine:3.20 AS downloader

ARG KOMARI_VERSION=1.1.40
ARG TARGETARCH

RUN apk add --no-cache curl

# 如 komari release 的命名和 TARGETARCH 不完全一致，可在这里加映射逻辑
RUN set -eux; \
    curl -fsSL -o /komari-agent \
      "https://github.com/komari-monitor/komari-agent/releases/download/${KOMARI_VERSION}/komari-agent-linux-${TARGETARCH}"; \
    chmod +x /komari-agent

# ---- runtime stage ----
FROM nginx:alpine

RUN apk add --no-cache tini

COPY --from=downloader /komari-agent /usr/local/bin/komari-agent
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
STOPSIGNAL SIGTERM

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]