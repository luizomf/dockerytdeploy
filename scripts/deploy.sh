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

APP_DIR="/dockerlabs"
BRANCH="main"

cd "$APP_DIR"

# Safety: ensure we are in the right repo
test -d .git

# Pull and deploy
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

# This sudo here bothers me, so I'm locking this command
# in for github in sudoers. (will talk about it in a minute).
sudo docker compose up -d --build

# Noiiiice 😚!!!
echo "OK: deployed $(git rev-parse --short HEAD)"
