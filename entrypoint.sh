#!/bin/sh
set -eu
set -o pipefail 2>/dev/null || true

: "${AGENT_ENDPOINT:?AGENT_ENDPOINT is required}"
: "${AGENT_TOKEN:?AGENT_TOKEN is required}"

log() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }

AGENT_PID=""
APP_PID=""

cleanup() {
  set +e
  log "Stopping processes..."
  [ -n "${APP_PID}" ] && kill -TERM "${APP_PID}" 2>/dev/null || true
  [ -n "${AGENT_PID}" ] && kill -TERM "${AGENT_PID}" 2>/dev/null || true

  [ -n "${APP_PID}" ] && wait "${APP_PID}" 2>/dev/null || true
  [ -n "${AGENT_PID}" ] && wait "${AGENT_PID}" 2>/dev/null || true
  log "Stopped."
}

trap cleanup INT TERM

log "Starting komari-agent..."
/usr/local/bin/komari-agent -e "${AGENT_ENDPOINT}" -t "${AGENT_TOKEN}" &
AGENT_PID=$!
log "komari-agent started (pid=${AGENT_PID})"

log "Starting node app..."
node index.js &
APP_PID=$!
log "node app started (pid=${APP_PID})"

# 任一进程退出就退出容器（更符合编排系统预期）
if wait -n "${AGENT_PID}" "${APP_PID}" 2>/dev/null; then
  EXIT_CODE=$?
else
  # BusyBox 兼容 fallback
  EXIT_CODE=0
  while :; do
    if ! kill -0 "${AGENT_PID}" 2>/dev/null; then
      err "komari-agent exited"
      EXIT_CODE=1
      break
    fi
    if ! kill -0 "${APP_PID}" 2>/dev/null; then
      err "node app exited"
      wait "${APP_PID}" || true
      EXIT_CODE=$?
      break
    fi
    sleep 1
  done
fi

cleanup
exit "${EXIT_CODE}"
