#!/usr/bin/env bash

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2026-01-01 <- 👀
# License: MIT
################################################################################

gunicorn src.dockerlabs.main:app -k \
  uvicorn.workers.UvicornWorker --bind "0.0.0.0:8000" \
  --workers 1 --timeout 60 --graceful-timeout 45 --preload \
  --keep-alive 10 --access-logfile /dev/null --error-logfile - \
  --log-level "warning"

