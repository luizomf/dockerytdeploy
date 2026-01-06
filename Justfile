# Configs
# set unstable
set export
set shell := ["bash", "-cu"]

ROOT_DIR := justfile_directory()

set dotenv-load := true
ENV_PATH := ROOT_DIR / '.env' # I could not use this as the dotenv-path
set dotenv-path := '.env' # That's why I'm repeating it here

################################################################################
# Tools
################################################################################

# List all just recipes
[group('Tools')]
@default:
  @just -l

# Write env variables to a template file using envsubst
[group('Tools')]
envsub:
  envsubst '${DC_DOCKERFILE} ${DC_COMPOSE}' \
    < "{{ ROOT_DIR }}/temp/template1.conf.template" \
    > '{{ ROOT_DIR }}/temp/template1.conf'

################################################################################
# Docker
################################################################################

# docker {{ ARGS }} (alias). E.g just dc ps -a
[group('Docker')]
dc *ARGS:
  @-docker {{ ARGS }}

# docker ps {{ ARGS }}
[group('Docker')]
dcp *ARGS:
  just dc ps {{ ARGS }}

# docker ps -a {{ ARGS }}
[group('Docker')]
dcpa *ARGS:
  just dcp -a {{ ARGS }}

# docker stop all containers {{ ARGS }}
[group('Docker')]
dcstopa *ARGS:
  -just dc stop $(just dcpa -q) {{ ARGS }}

# docker REMOVE/DELETE all containers {{ ARGS }}
[group('Docker')]
dcrma *ARGS: dcstopa
  -just dc rm $(just dcpa -q) {{ ARGS }}

# docker PRUNE the whole system {{ ARGS }}
[group('Docker')]
dcprune *ARGS: dcrma
  @just dc system prune -f {{ ARGS }}

################################################################################
# Docker Build
################################################################################

# docker build {{ ARGS }}
[group('Docker Build')]
dcb *ARGS:
  just dc build {{ ROOT_DIR }} \
    -f "{{ ROOT_DIR }}/${DC_DOCKERFILE}" \
    -t "${DC_APP_IMAGE_NAME}" \
    {{ ARGS }}

################################################################################
# Docker Run
################################################################################

# docker run --rm ${DC_APP_IMAGE_NAME} {{ ARGS }}
[group('Docker Run')]
dcr *ARGS:
  just dc run --rm "${DC_APP_IMAGE_NAME}" \
    {{ ARGS }}

# docker run --rm -it ${DC_APP_IMAGE_NAME} {{ ARGS }}
[group('Docker Run')]
dcrit *ARGS:
  just dc run --rm -it \
    "${DC_APP_IMAGE_NAME}" \
    {{ ARGS }}

# docker run --rm -it ${DC_APP_IMAGE_NAME} bash {{ ARGS }}
[group('Docker Run')]
dcrbash *ARGS:
  just dcrit bash {{ ARGS }}

# docker run --rm -it ${DC_APP_IMAGE_NAME} sh {{ ARGS }}
[group('Docker Run')]
dcrsh *ARGS:
  just dcrit sh {{ ARGS }}

################################################################################
# Docker Image
################################################################################

# docker image {{ ARGS }} (alias). E.g just dci ls
[group('Docker Image')]
dci *ARGS:
  just dc image {{ ARGS }}

# docker image {{ ARGS }} (alias). E.g just dci ls
[group('Docker Image')]
dcil *ARGS:
  just dc image ls {{ ARGS }}

# docker image rm {{ ARGS }}
[group('Docker Image')]
dcirm *ARGS:
  just dc image rm {{ ARGS }}

# docker image REMOVE ALL IMAGES {{ ARGS }}
[group('Docker Image')]
dcirma *ARGS:
  just dc image rm $(just dcil -q) {{ ARGS }}

################################################################################
# Docker Compose
################################################################################

# docker compose {{ ARGS }} (alias). E.g just dcc up -d
[group('Docker Compose')]
dcc *ARGS:
  just dc compose --env-file "{{ ENV_PATH }}" {{ ARGS }}

# docker compose up {{ ARGS }}
[group('Docker Compose')]
dccup *ARGS:
  just dcc up {{ ARGS }}

# docker compose up -d {{ ARGS }}
[group('Docker Compose')]
dccuw *ARGS:
  just dccup -w {{ ARGS }}

# docker compose up -d {{ ARGS }}
[group('Docker Compose')]
dccupd *ARGS:
  just dccup -d {{ ARGS }}

# docker compose up -d --build {{ ARGS }}
[group('Docker Compose')]
dccupdb *ARGS:
  just dccupd --build {{ ARGS }}

# docker compose up --build {{ ARGS }}
[group('Docker Compose')]
dccupb *ARGS:
  just dccup --build {{ ARGS }}

# docker compose up --build -d {{ ARGS }}
[group('Docker Compose')]
dccupbd *ARGS:
  just dccupb -d {{ ARGS }}

# docker compose down {{ ARGS }}
[group('Docker Compose')]
dccdown *ARGS:
  just dcc down {{ ARGS }}

# docker compose scale ${DC_APP_CONTAINER_NAME}={{ INT }}
[group('Docker Compose')]
dccscale INT:
  just dcc scale ${DC_APP_CONTAINER_NAME}={{ INT }}

# docker compose exec -it nginx sh
[group('Docker Compose')]
dccnginx *ARGS:
  just dcc exec -it nginx sh {{ ARGS }}

# docker compose exec -it nginx sh
[group('Docker Compose')]
dcccertbot *ARGS:
  just dcc exec -it certbot sh {{ ARGS }}

# # uv run {{ ARGS }}. E.g. just run python -VV
# [group('Run')]
# @run *ARGS:
#   uv run {{ ARGS }}
#
# # uv sync {{ ARGS }}. E.g. just sync --all-pacages --no-install-project
# [group('Setup')]
# [no-cd]
# @sync *ARGS:
#   uv sync {{ ARGS }}
#
# # uv init {{ ARGS }}. E.g. just init --name="nice" --description=\"That's nice!\"
# [group('Setup')]
# [no-cd]
# init *ARGS:
#   uv init --package {{ ARGS }}
#
# # docker compose (alias). E.g just dcc up -d
# [group('Docker')]
# dcc *ARGS:
#   just dc compose --env-file=env/.env -f {{dc_compose_path}} {{ARGS}}
#
# # start the container
# [group('Docker')]
# dcstart:
#   just dc start {{dc_container_name}}
#
# # docker compose up {{ ARGS }}
# [group('Docker')]
# dccup *ARGS: dccdown
#   just dcc up {{ARGS}}
#
# # docker compose scale {{dc_container_name}}=INT
# [group('Docker')]
# dccscale INT:
#   just dcc scale {{dc_container_name}}={{INT}}
#
# # docker compose down {{ ARGS }}
# [group('Docker')]
# dccdown *ARGS:
#   just dcc down {{ARGS}}
#
# # docker compose up --build {{ ARGS }}
# [group('Docker')]
# dccupb *ARGS:
#   just dccup --build {{ARGS}}
#
# # docker compose up --detach --build {{ ARGS }}
# [group('Docker')]
# dccupbd *ARGS:
#   just dccupb -d {{ARGS}}
#
# # docker compose up --detach {{ ARGS }}
# [group('Docker')]
# dccupd *ARGS:
#   just dccup -d {{ARGS}}
#
# @_dcexec *ARGS:
#   just dcstart
#   just dcc exec -it {{dc_container_name}} {{ARGS}}
#
# # It will build and start the container if it does not exit
# [group('Docker')]
# dcexec *ARGS:
#   if test -z $(docker container ls -q -a --filter name={{ dc_container_name }}); then \
#     just dcbuild ; \
#     just dccup -d ; \
#     just _dcexec {{ ARGS }} ; \
#   else \
#     just _dcexec {{ ARGS }} ; \
#   fi
#
# _dcrun *ARGS:
#   just dc run --rm -it {{dc_image_name}} {{ARGS}}
#
# # It will build the image if it does not exit
# [group('Docker')]
# dcrun *ARGS:
#   if test -z $(docker image ls -q {{ dc_image_name }}); then \
#     just dcbuild ; \
#     just _dcrun {{ ARGS }} ; \
#   else \
#     just _dcrun {{ ARGS }} ; \
#   fi
#
# # Delete image, container and prompt a system prune
# [group('Docker')]
# dcnuke:
#   -just dc stop $(docker ps -q -a)
#   -docker rmi {{dc_image_name}}
#   -docker rm {{dc_container_name}}
#   -docker system prune
#
# # Uses curl use the base_url{{ ARGS }}
# [group('Request')]
# get *ARGS:
#   #!/usr/bin/env bash
#   RES=$(curl -s {{ base_url }}{{ ARGS }})
#   echo $RES
