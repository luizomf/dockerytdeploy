#!/usr/bin/env bash

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2026-01-01 <- 👀
# License: MIT
################################################################################

set -Eeuo pipefail

catch_errors() {
  local rc=$?
  printf '\nERROR:\nsrc=%s\nline=%s\nrc=%s\ncmd=%b\n\n' \
    "${BASH_SOURCE[0]}" "$LINENO" "$rc" "$BASH_COMMAND" >&2
  exit "$rc"
}

trap catch_errors ERR

repo_root="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./variables.sh
source "${repo_root}/scripts/variables.sh"

warn "This script is intentionally annoying. IT WILL DELETE THINGS."

# Refuse to run if not in a TTY
# This prevents dumb piping/automation surprises (like the yes command)
[[ -t 0 ]] || die "Refusing to run without a TTY."

# Must be executed from repo root
[[ -d "$repo_root/.git" ]] || die "Not inside the expected repo."
cd "$repo_root"

# Explicit opt-in: require RUN=1
[[ "${RUN:-}" == "1" ]] || die "Set RUN=1 to confirm you want to run this."

# Explicit phrase confirmation (annoying on purpose)
ask "Type 'y' to delete everything:"
read -r -p "" confirm
[[ "$confirm" == "y" ]] || die "Confirmation failed."

# Optional extra: must pass --i-know-what-im-doing
[[ "${1:-}" == "--i-know-what-im-doing" ]] || die "Pass --i-know-what-im-doing."

dc_down
docker rm -f "$(docker ps -q -a)" >/dev/null 2>&1 || true
docker rmi -f "$(docker image ls -q)" >/dev/null 2>&1 || true
docker builder prune -f >/dev/null 2>&1 || true
docker system prune -f >/dev/null 2>&1 || true
docker network prune -f >/dev/null 2>&1 || true

sudo rm -Rf "$SSL_DIR"

