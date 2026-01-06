#!/usr/bin/env bash

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2026-01-01 <- 👀
# License: MIT
################################################################################

SCRIPT_DIRECTORY="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

ROOT_DIR=$(dirname "${SCRIPT_DIRECTORY}")
readonly ROOT_DIR

SSL_DIR="${ROOT_DIR}/ssl_conf"
readonly SSL_DIR

readonly CERTBOT_DIR="${SSL_DIR}/certbot"
readonly CONF_DIR="${CERTBOT_DIR}/conf"

# shellcheck disable=2034
readonly DH_PARAMS_FILE="${CONF_DIR}/ssl-dhparams.pem"
# shellcheck disable=2034
readonly NGINX_SSL_CONF_FILE="${CONF_DIR}/options-ssl-nginx.conf"

readonly NGINX_DIR="${ROOT_DIR}/nginx"
readonly NGINX_TEMPLATES_DIR="${NGINX_DIR}/templates"
readonly NGINX_CONFD_DIR="${NGINX_DIR}/conf.d"

# shellcheck source=../.env
ENV_FILE="${ROOT_DIR}/.env"
readonly ENV_FILE

# Utility functions
# shellcheck source=utils.sh
source "${ROOT_DIR}/scripts/utils.sh"

[[ -f "$ENV_FILE" ]] || die "Missing env file: $ENV_FILE (copy from .env.example)"

# shellcheck source=../.env
source "$ENV_FILE"

COMPOSE_FILE="${ROOT_DIR}/${DC_COMPOSE}"
# shellcheck disable=2034
readonly COMPOSE_FILE

CURRENT_ENV="${CURRENT_ENV:-}"
[[ -n "$CURRENT_ENV" ]] || die "Missing CURRENT_ENV in $ENV_FILE (expected: production|development)"

case "$CURRENT_ENV" in
  production|development) ;;
  *) die "Invalid CURRENT_ENV='$CURRENT_ENV' (expected: production|development)" ;;
esac

readonly DEV_CERT_DIR="${SSL_DIR}/${CURRENT_ENV}"
readonly DEV_CERT_PRIV_FILE="${DEV_CERT_DIR}/privkey.pem"
readonly DEV_CERT_CHAIN_FILE="${DEV_CERT_DIR}/fullchain.pem"

CERTBOT_CMD="certbot certonly "
CERTBOT_CMD="${CERTBOT_CMD} --webroot -w /var/www/certbot "
CERTBOT_CMD="${CERTBOT_CMD} --email ${EMAIL} "
CERTBOT_CMD="${CERTBOT_CMD} --rsa-key-size 4096 --agree-tos --force-renewal "
CERTBOT_CMD="${CERTBOT_CMD} --cert-name ${CURRENT_ENV} --expand -n "

DC=""
if have_cmd docker && docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif have_cmd docker-compose; then
  DC="docker-compose"
else
  die "Could not find 'docker compose' or 'docker-compose'. Install Docker/Compose."
fi

RAW_GH_CONT_URL="https://raw.githubusercontent.com"

NGINX_SSL_CONF_URL="${RAW_GH_CONT_URL}/certbot/certbot/refs/heads/main/certbot-nginx"
NGINX_SSL_CONF_URL="${NGINX_SSL_CONF_URL}/src/certbot_nginx/_internal/tls_configs"
NGINX_SSL_CONF_URL="${NGINX_SSL_CONF_URL}/options-ssl-nginx.conf"

DH_PARAMS_URL="${RAW_GH_CONT_URL}/certbot/certbot/refs/heads/main/certbot/src/"
DH_PARAMS_URL="${DH_PARAMS_URL}certbot/ssl-dhparams.pem"

OPENSSL_CMD="openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout"
OPENSSL_CMD="${OPENSSL_CMD} $DEV_CERT_PRIV_FILE -out "
OPENSSL_CMD="${OPENSSL_CMD} $DEV_CERT_CHAIN_FILE -subj /CN=localhost"
