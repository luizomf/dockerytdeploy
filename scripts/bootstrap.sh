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
SCRIPT_DIRECTORY="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIRECTORY}/variables.sh"

# Checking because we are going to delete, edit or create files
ask "Run '${BASH_SOURCE[0]}' for '${CURRENT_ENV}' environment?"
read -rp "" decision

if [[ $decision != 'y' ]]; then
  success "Ok, bye 👋"
  exit 0
fi

success "Using compose command: $DC"
info "Environment: $CURRENT_ENV"

# Download ssl config for nginx. This will be imported from
# nginx server block (port 443)
if ! [[ -e "$NGINX_SSL_CONF_FILE" ]]; then
  info "Creating Nginx SSL Configuration File"
  run_cmd "mkdir -p \"$(dirname "$NGINX_SSL_CONF_FILE")\""
  run_cmd "curl \"$NGINX_SSL_CONF_URL\" > \"$NGINX_SSL_CONF_FILE\""
fi

# Download the Diffie-Hellman Parameters File
# This will also be imported from nginx server block (port 443)
if ! [[ -e "$DH_PARAMS_FILE" ]]; then
  info "Creating Diffie-Hellman Parameters File"
  run_cmd "mkdir -p \"$(dirname "$DH_PARAMS_FILE")\""
  run_cmd "curl \"$DH_PARAMS_URL\" > \"$DH_PARAMS_FILE\""
fi

# Create directories and run the openssl command to create the
# dummy self signed dev SSL certificates.
info "Generating self signed certificates for env '${CURRENT_ENV}'"
run_cmd "mkdir -p \"$(dirname "$DEV_CERT_CHAIN_FILE")\""
run_cmd "$OPENSSL_CMD"

# When working in development mode, we won't use the nginx server
# name directive (no domains).
if [[ $CURRENT_ENV == 'development' ]]; then
  info "Environment is ${CURRENT_ENV}, then DOMAINS='_'"
  DOMAINS='_'

  warn "Browser will complain about self-signed SSL certificates"
fi

# Create the NGINX conf.d directory and our main app.conf.
info "Create the NGINX conf.d directory and our main app.conf"
run_cmd "mkdir -p \"${NGINX_CONFD_DIR}\""
run_cmd "touch \"${NGINX_CONFD_DIR}/app.conf\""

if [[ $CURRENT_ENV == 'production' ]]; then
  # When in production, run nginx server in http-only mode (port 80).
  # That allows certbot to acknowledge our domains to create the SSL
  # certificates. Here we are the good guys 😇.
  info "Creating temporary HTTP-only nginx config for the ACME challenge"
  create_nginx_conf "app.http-only.conf.template"
  # After certbot create our real certificates, we'll add the rest (443)
else
  # When in development, run nginx normally in https mode (port 443).
  # In practice, the difference is that self signed SSL certificates
  # has no acknowledgement. In that mode, we are criminals 😈.
  create_nginx_conf
fi

if [[ $CURRENT_ENV == 'production' ]]; then
  info "Generating letsencrypt certificates for env '${CURRENT_ENV}'"
  # We restart here to ensure we are using the correct config for
  # the correct situation. We don't wanna go to the church ⛪️ in
  # speedos 🩲.
  restart_nginx

  # Append our domains to the certbot command
  for domain in $DOMAINS ; do
    info "Appending -d '$domain' to certbot command"
    CERTBOT_CMD+=" -d ${domain}"
  done

  # Oh boy! Got so many errors here. Seems like it is
  # working now 🤌
  # TIP: The http-only server for certbot solved all the problems.
  # When I created this code, I was mixing the two servers 80/443.
  dc_run --entrypoint "\"${CERTBOT_CMD}\"" certbot
  # Now we fly first class ✈️
  create_nginx_conf
  dc_exec nginx nginx -s reload
fi

# Since we are here, I'm restarting everything for you. If you're
# afraid of downtime, that is gonna hurt for 10 seconds.
rebuild_all_containers
