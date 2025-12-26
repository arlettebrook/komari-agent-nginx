#!/bin/sh
set -eu
# BusyBox ash 通常支持 pipefail；不支持也不影响
set -o pipefail 2>/dev/null || true

: "${AGENT_ENDPOINT:?AGENT_ENDPOINT is required}"
: "${AGENT_TOKEN:?AGENT_TOKEN is required}"

log() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }

AGENT_PID=""
NGINX_PID=""

cleanup() {
  # 避免重复执行时出错
  set +e

  log "Stopping processes..."
  [ -n "${NGINX_PID}" ] && kill -TERM "${NGINX_PID}" 2>/dev/null || true
  [ -n "${AGENT_PID}" ] && kill -TERM "${AGENT_PID}" 2>/dev/null || true

  # 等待退出
  [ -n "${NGINX_PID}" ] && wait "${NGINX_PID}" 2>/dev/null || true
  [ -n "${AGENT_PID}" ] && wait "${AGENT_PID}" 2>/dev/null || true

  log "Stopped."
}

trap cleanup INT TERM

log "Starting komari-agent..."
/usr/local/bin/komari-agent \
  -e "${AGENT_ENDPOINT}" \
  -t "${AGENT_TOKEN}" &
AGENT_PID=$!
log "komari-agent started (pid=${AGENT_PID})"

log "Starting nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!
log "nginx started (pid=${NGINX_PID})"

# 等待任一进程退出；BusyBox 的 wait 是否支持 -n 取决于版本，所以做兼容
if wait -n "${AGENT_PID}" "${NGINX_PID}" 2>/dev/null; then
  EXIT_CODE=$?
else
  # fallback：轮询
  EXIT_CODE=0
  while :; do
    if ! kill -0 "${AGENT_PID}" 2>/dev/null; then
      err "komari-agent exited"
      EXIT_CODE=1
      break
    fi
    if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
      err "nginx exited"
      wait "${NGINX_PID}" || true
      EXIT_CODE=$?
      break
    fi
    sleep 1
  done
fi

# 有一个先退出了，就关掉另一个并退出
cleanup
exit "${EXIT_CODE}"