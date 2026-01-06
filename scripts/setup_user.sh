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

# shellcheck source-path=scripts
SCRIPTS_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${SCRIPTS_DIR}/utils.sh"

# Fallback check
if grep -q _USER_ALREADY_CONFIGURED "$HOME/.bashrc"; then
  die "User $USER is already configured. Please, run: source ~/.bashrc"
fi

_FOR_BASHRC=''

ask "Enable vim-mode? [y/n]: "
read -rp "" ENABLE_VIM_MODE

append_bashrc_line() {
  local line="$1"
  printf -v _FOR_BASHRC "%s%s\n" "${_FOR_BASHRC}" "${line}"
}

if [[ ${ENABLE_VIM_MODE:-} = y ]]; then
  append_bashrc_line "set -o vi"

  ask "Enable key bind 'jj' -> 'ESC' on vim-mode? [y/n]: "
  read -rp "" ENABLE_JJ_KEYBIND
fi

if [[ ${ENABLE_JJ_KEYBIND:-} = y ]]; then
  append_bashrc_line "bind -m vi-insert '\"jj\": vi-movement-mode'"
fi

if ! [[ -z ${_FOR_BASHRC:-} ]]; then
  info "Writing config to ${HOME}/.bashrc for user $USER"
  append_bashrc_line "export _USER_ALREADY_CONFIGURED=1"
  _FOR_BASHRC=$(printf "%s" "$_FOR_BASHRC" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  printf "%b" "${_FOR_BASHRC}" >> "${HOME}/.bashrc"
fi

info "User $USER. User must run: source ~/.bashrc"
info "Creating ${HOME}/.vimrc"
cat "${SCRIPTS_DIR}/.vimrc" > "${HOME}/.vimrc"
info "Created ${HOME}/.vimrc"

info "Creating ${HOME}/.tmux.conf"
cat "${SCRIPTS_DIR}/.tmux.conf" > "${HOME}/.tmux.conf"
info "Created ${HOME}/.tmux.conf"

echo
info "Everything is setup, please run the following commands:"
echo
info "source ~/.bashrc"
info "tmux source ~/.tmux.conf"
echo
