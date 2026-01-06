#!/usr/bin/env sh

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2026-01-01 <- 👀
# License: MIT
################################################################################

set -eu

INTERVAL="6h" # Default: 6h
INITIAL_RUN=1 # Default: 1
INITIAL_DELAY="10m" # Default: 10m

log() { echo "[$(date -Is)] nginx: $*"; }

trap 'log "TERM/INT received, exiting"; exit 0' TERM INT

maybe_sleep() {
  if [ -n "${1:-}" ]; then
    log "sleeping $1"
    sleep "$1"
  fi
}

reload_loop() {
  if [ "$INITIAL_RUN" -eq 1 ]; then
    maybe_sleep "$INITIAL_DELAY"
    log "initial reload"
    nginx -s reload || log "reload failed (exit=$?)"
  fi

  while :; do
    maybe_sleep "$INTERVAL"
    log "reload"
    nginx -s reload || log "reload failed (exit=$?)"
  done
}

reload_loop &

log "starting nginx (foreground)"
exec nginx -g "daemon off;"
