#!/usr/bin/env bash

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2026-01-01 <- 👀
# License: MIT
################################################################################

# ANSI Colors and styles
readonly INFO="\e[38;5;6m"
readonly SUCCESS="\e[38;5;2m"
readonly WARN="\e[38;5;3m"
readonly LOG_CMD="\e[38;5;5m"
readonly ASK="\e[38;5;4m"
readonly ERROR="\e[38;5;1m"
readonly RES="\e[0m"
readonly DIM="\e[2m"

# Stdout and Stderr logging functions
readonly tag_pad=10
readonly tag_sep=":"

pad_right() {
  str="${1:-}"
  width="${2:-$tag_pad}"
  printf "%-${width}s\n" "$str"
}

log() {
  printf "%b" "${*}\n"
}

die() {
  error "${*}"
  exit 1
}

error() {
  log "${ERROR}$(pad_right "[ERROR]" $tag_pad)$tag_sep$RES ${*}" >&2
}

info() {
  log "${INFO}$(pad_right "[INFO]" $tag_pad)$tag_sep$RES $*"
}

success() {
  log "${SUCCESS}$(pad_right "[DONE]" $tag_pad)$tag_sep$RES $*"
}

warn() {
  log "${WARN}$(pad_right "[WARN]" $tag_pad)$tag_sep$RES $*"
}

ask() {
  log "${ASK}$(pad_right "[QUESTION]" $tag_pad)$tag_sep$RES" "$* ${DIM}[y/n]: ${RES}"
}

log_cmd() {
  log "${LOG_CMD}$(pad_right "[CMD]" $tag_pad)$tag_sep$RES $*"
}

have_cmd() {
  log_cmd command -v "$1" >/dev/null 2>&1
  command -v "$1" >/dev/null 2>&1
}

run_cmd() {
  log_cmd "$*"
  /usr/bin/env bash -c "${@}"
}

join_cmd() {
  local output=""
  local part

  for part in "$@"; do
    output+=" $(printf '%b' "$part")"
  done

  printf '%s' "${output# }"
}

nginx_info() {
  info "Check Nginx container info"
  log_cmd docker ps -f name=nginx
  docker ps -f name=nginx
}

container_up_or_die() {
  CONTAINER_NAME=$1

  info "Checking if '${CONTAINER_NAME}' container is up"

  # Check if the container is running
  if [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)" == "running" ]; then
      success "Container '$CONTAINER_NAME' is running."
  else
      die "Container '$CONTAINER_NAME' is not running."
  fi
}

create_nginx_conf() {
  info "Creating Nginx config file"

  local template_name="${1:-app.conf.template}"
  local output_name="${2:-app.conf}"
  local template_path="${NGINX_TEMPLATES_DIR}/${template_name}"
  local output_path="${NGINX_CONFD_DIR}/${output_name}"

  [[ -f "$template_path" ]] || die "Missing nginx template: $template_path"
  run_cmd "mkdir -p \"$(dirname "$output_path")\""

  info "Creating Nginx Config from template files"
  info "envsubst ... < $template_path > $output_path"

  # shellcheck disable=SC2016
  DOMAINS=$DOMAINS CURRENT_ENV=$CURRENT_ENV \
    DC_APP_CONTAINER_NAME=$DC_APP_CONTAINER_NAME \
    envsubst '${DOMAINS} ${CURRENT_ENV} ${DC_APP_CONTAINER_NAME}' \
    < "$template_path" \
    > "$output_path"

  success "Done creating Nginx Config Files"
}

dc_run() {
  [[ $# -gt 0 ]] || die "dc_run requires arguments"
  run_cmd "$(join_cmd "$DC" "--env-file" "$ENV_FILE" "-f" "$COMPOSE_FILE" run --rm "$@")"
}

dc_exec() {
  [[ $# -ge 2 ]] || die "dc_exec requires a service name and command"
  local service="$1"
  shift
  run_cmd "$(join_cmd "$DC" "--env-file" "$ENV_FILE" "-f" "$COMPOSE_FILE" exec "$service" "$@")"
}

dc_up() {
  [[ $# -gt 0 ]] || die "dc_up requires at least one service"
  run_cmd "$(join_cmd "$DC" "--env-file" "$ENV_FILE" "-f" "$COMPOSE_FILE" up -d "$@")"
}

dc_down() {
  run_cmd "$(join_cmd "$DC" "--env-file" "$ENV_FILE" "-f" "$COMPOSE_FILE" stop "$@")"
}

restart_nginx() {
  info "Restarting nginx container"
  dc_down "nginx"
  dc_up "nginx"
  container_up_or_die "nginx"
}


rebuild_all_containers() {
  info "Rebuilding all containers"
  dc_down
  dc_up --build --force-recreate --remove-orphans

  container_up_or_die "nginx"
  container_up_or_die "certbot"
}
