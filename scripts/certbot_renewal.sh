#!/usr/bin/env sh

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2026-01-01 <- 👀
# License: MIT
################################################################################

set -eu

INTERVAL="12h" # Default: 12h
INITIAL_RUN=1 # Default: 1
INITIAL_DELAY="10m" # Default: 10m

QUIET=1 # 1 quiet, 0 verbose (Default: 1)

log() { echo "[$(date -Is)] certbot: $*"; }

trap 'log "TERM/INT received, exiting"; exit 0' TERM INT

maybe_sleep() {
  if [ -n "${1:-}" ]; then
    log "sleeping $1"
    sleep "$1"
  fi
}

run_renew() {
  if [ "$QUIET" -eq 1 ]; then
    certbot renew --quiet
  else
    certbot renew -v
  fi
}

if [ "$INITIAL_RUN" -eq 1 ]; then
  maybe_sleep "$INITIAL_DELAY"
  log "initial renew"
  run_renew || log "renew failed (exit=$?)"
fi

while :; do
  maybe_sleep "$INTERVAL"
  log "renew"
  run_renew || log "renew failed (exit=$?)"
done
