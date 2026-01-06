# Modern Python App Deploy (Video 3)

This repository is the **third** installment of the "Docker do Zero ao Avançado"
YouTube series. Part 1 built a local FastAPI app with Docker/UV, part 2 hardened
a Google Cloud VM, and this repo ties everything together: automated container
builds, NGINX + Let's Encrypt, and GitHub Actions-based deploys to the
production server created in video two.

> If you are following along with the series, keep the public Video 1 repo
> (`luizomf/dockeryt`) untouched. All production changes live here so the
> recorded content stays consistent.

---

## Stack at a Glance

- **Application**: FastAPI (`src/dockerlabs/main.py`), served by Gunicorn +
  `uvicorn.workers.UvicornWorker`.
- **Container orchestration**: Docker Compose (single file, no swarm).
- **Reverse proxy**: NGINX (TLS termination, load-balancing to two app
  containers, health checks, hot reload loop).
- **Certificates**: Let's Encrypt via Certbot (`scripts/certbot_renewal.sh`)
  with development fallback using self-signed certs.
- **Automation**: Bash scripts under `scripts/` + GitHub Actions deploy job.
- **Target host**: GCP Compute Engine VM (`Ubuntu 24.04 LTS`, `e2-medium`,
  static IP `34.61.67.116`, domains `app1.otaviomiranda.com`,
  `app2.otaviomiranda.com`).

---

## Repository Layout

```
├─ compose.yaml                # App, nginx, certbot services (production + dev)
├─ Dockerfile                  # Multi-stage build (dev target used by compose)
├─ scripts/
│  ├─ bootstrap.sh             # Generates certs + NGINX configs per environment
│  ├─ deploy.sh                # Server-side deploy command (git pull + compose)
│  ├─ certbot_renewal.sh       # Renewal loop run by certbot container
│  ├─ nginx_renewal.sh         # Background nginx reload loop
│  └─ setup_user.sh            # Optional dotfile/bootstrap for shell users
├─ nginx/
│  ├─ nginx.conf               # Base config
│  └─ templates/*.template     # Rendered via bootstrap.sh (http-only/https)
├─ ssl_conf/                   # Let’s Encrypt + dummy cert storage
├─ DEPLOY.md                   # Full server provisioning + GitHub Action guide
└─ AGENTS.md                   # Project goals/scope for collaborators
```

---

## Prerequisites

| Where  | Requirements                                                                                       |
| ------ | -------------------------------------------------------------------------------------------------- |
| Local  | Docker Engine + Docker Compose plugin, `uv` (optional), POSIX shell, `bash`, `curl`, `openssl`     |
| Server | Ubuntu 24.04 LTS VM with Docker CE, Fail2Ban, UFW (opening 22/80/443), project dir `/dockerlabsp2` |
| GitHub | Repo secrets `HOST`, `PORT`, `USER`, `KEY` for deploy workflow                                     |

See `DEPLOY.md` for the exact provisioning steps (users, permissions, sudoers,
SSH hardening, Fail2Ban, firewall, Git config, etc.).

---

## Getting Started Locally

**Clone & Env Vars**

```sh
git clone git@github.com:luizomf/dockerlabsp2.git
cd dockerlabsp2
cp .env.example .env
# adjust CURRENT_ENV=development, DOMAINS (space separated), EMAIL, etc.
```

**Bootstrap SSL + NGINX config**

```sh
./scripts/bootstrap.sh
```

- Prompts before touching files.
- Downloads the official `options-ssl-nginx.conf` + dhparams if missing.
- Generates dummy TLS certs (`ssl_conf/development/`) when
  `CURRENT_ENV=development`.
- Renders `nginx/conf.d/app.conf` pointing to your domains or `_` (dev).

**Start the stack**

```sh
docker compose up -d --build
docker ps
```

**Verify**

- `curl -k https://localhost/` (self-signed warning is expected in dev).
- `curl http://localhost:8000/health` (direct container health endpoint).

Re-run `scripts/bootstrap.sh` whenever you change domains or switch
environments.

---

## Production Bootstrap Flow

All detailed commands live in `DEPLOY.md`. High level:

1. Provision the VM (done in Video 2) and clone this repo into `/dockerlabsp2`.
2. Copy `.env.example` → `.env`, set `CURRENT_ENV=development` for the first
   run.
3. Run `./scripts/bootstrap.sh` to create dummy certs + configs, then
   `sudo docker compose up -d --build`.
4. When satisfied, set `CURRENT_ENV=production`, re-run `./scripts/bootstrap.sh`
   to request Let’s Encrypt certificates. DNS `A` records must point to the VM.
5. Confirm `docker logs certbot` shows a successful issuance and that NGINX
   reloads (`docker logs nginx`).
6. Reboot the server once to ensure `restart: unless-stopped` containers
   (app/nginx/certbot) come back automatically.

---

## Deployment Automation

- GitHub Action: `.github/workflows/deploy.yaml` (pinned
  `appleboy/ssh-action@23bd972…`).
- Trigger: push to `main`.
- Action connects as the locked-down `github` user using the secrets above and
  runs the forced command `/usr/local/bin/deploy.sh` which:
  1. `cd /dockerlabsp2`
  2. `git fetch/reset` the requested branch (default `main`)
  3. `sudo docker compose up -d --build`

Update `deploy.sh` if you change the project path/branch, but keep the forced
command + sudoers entry aligned with the hardening described in `DEPLOY.md`.

---

## Maintenance & Scripts

| Script                       | Purpose                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------- |
| `scripts/bootstrap.sh`       | Downloads SSL config, generates dummy certs, handles Let’s Encrypt issuance, restarts NGINX |
| `scripts/certbot_renewal.sh` | Runs inside certbot container; renews every 12h (configurable)                              |
| `scripts/nginx_renewal.sh`   | Runs inside nginx container; reloads every 6h so renewed certs are picked up                |
| `scripts/deploy.sh`          | Server-side deploy command executed via forced SSH                                          |
| `scripts/setup_user.sh`      | Optional helper to configure shell/vi-mode/tmux/vim for local accounts                      |

All scripts use `set -euo pipefail` (or `-eu` for POSIX sh) and utilities in
`scripts/utils.sh`. Review those helpers before extending the tooling.

---

## Troubleshooting

- **Certbot fails to obtain certs**
  - Ensure `CURRENT_ENV=production`, DNS points to the VM, ports 80/443 open,
    and NGINX temporary HTTP config exists (`bootstrap.sh` handles this).
  - Check `docker logs certbot` for ACME challenge errors.
- **After reboot, certbot/NGINX didn't start**
  - Both services use `restart: unless-stopped`. If a container keeps exiting,
    inspect logs; you may have missing cert files or corrupted config.
- **GitHub Action can't deploy**
  - Verify secrets, SSH key restrictions in `authorized_keys`, and that
    `/usr/local/bin/deploy.sh` is executable by root but readable by the deploy
    user. Tail `/var/log/auth.log` for SSH forced-command errors.

---

## More Resources

- **Video 1** (base Docker project): https://github.com/luizomf/dockeryt
- **Video 2** (server hardening walkthrough):
  <https://www.youtube.com/watch?v=IeyO3TnHcaw>
- **DEPLOY.md**: in-depth guide for provisioning, bootstrapping, GitHub Actions,
  and troubleshooting.
- **AGENTS.md**: project goals, security constraints, and expectations for
  contributors.

Feel free to open issues or PRs if you spot improvements, but keep in mind the
main goal: teach production-ready Docker deployments with a focus on
infrastructure clarity, not app complexity. Happy hacking!
