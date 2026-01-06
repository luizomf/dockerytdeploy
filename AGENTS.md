# AGENTS

This document keeps future collaborators aligned on the goals, guardrails, and
deployment story of this repo.

## Mission

- This is the code for the **third** video of a three-part YouTube series that
  takes students from zero to a production-ready Docker deployment of a Python
  app (`fastapi` + `uvicorn` + `uvloop` + `gunicorn`).
- Video 1 code lives in https://github.com/luizomf/dockeryt and must **not**
  drift; this private repo is free to evolve as long as it remains compatible
  with the teaching narrative.
- Video 2 provisioned the target VM on GCP (Compute Engine, Ubuntu 24.04 LTS,
  e2-medium, 10 GB disk, ports 22/80/443 open, IP `34.61.67.116`, domains
  `app1.otaviomiranda.com` + `app2.otaviomiranda.com`). Keep infra changes
  aligned with that setup.

## Current Focus (Video 3)

- Bridge the local Docker setup (Video 1) with the hardened server (Video 2):
  - Services: `dockerlabs` app container, `nginx` (fronts all traffic + reverse
    proxy), `certbot` (obtain/renew Let’s Encrypt certificates).
  - `psql` demo container was removed; don’t reintroduce unless the script
    requires it.
- Validate security and robustness of the deployment artifacts already in this
  repo (`Dockerfile`, `compose.yaml`, `scripts/bootstrap.sh`, NGINX config,
  Certbot flow). Look for improvements but preserve the educational storyline.

## Server + Access Ground Rules

- Users: personal admin user + locked-down `github` deploy user.
- `github` may only execute `/usr/local/bin/deploy.sh` via SSH;
  `authorized_keys` entry uses `restrict`, no port/agent/X11 forwarding, no
  PTTY, and a forced command.
- `deploy.sh` (`root:root`, `755`) does:
  1. `cd /dockerlabsp2`
  2. `git fetch/reset` against `origin/main`
  3. `sudo docker compose up -d --build`
- `sudoers`:
  `github ALL=(root:root) NOPASSWD:/usr/bin/docker compose up -d --build` — do
  not widen this without a security review.
- Baseline hardening already in place: SSH key-only auth with hardened
  `sshd_config`, Fail2Ban (sshd jail), UFW (allow 22/80/443), SetGID project
  folder (`/dockerlabsp2`, group `project`, `775`).

## Workflow Expectations

1. **Local dev** mirrors production Compose setup. `.env` resides at repo root;
   `.env.example` must stay updated with every new variable.
2. **Bootstrap script** (`scripts/bootstrap.sh`) generates dummy self-signed
   certs when `CURRENT_ENV=development` and real Let’s Encrypt certs in
   production. Keep this idempotent; it unblocks new students.
3. **CI/CD** happens via GitHub Actions (`.github/workflows/deploy.yaml`) using
   `appleboy/ssh-action@23bd972...` pinned SHA; secrets: `HOST`, `USER`, `KEY`,
   `PORT`. Any automation change must keep “push to `main` → deploy” working.
4. **Testing**: before turning `CURRENT_ENV` to `production`, verify containers
   build locally (`docker compose up -d --build`), NGINX routes HTTP traffic,
   and dummy SSL certs exist.

## Contribution Guidelines

- Favor infra clarity over app features—the series teaches Docker + deployment,
  not FastAPI specifics.
- Document every meaningful infra change in `README.md` or `DEPLOY.md`; future
  viewers will replicate steps verbatim.
- Keep comments concise and purposeful; avoid clutter in scripts and Compose.
- Respect existing security posture. If you must relax a control (e.g., broader
  sudo permissions), document why and add compensating safeguards.
- When uncertain about server state, assume the VM was restored from a snapshot
  right after Video 2; scripts should bring it to the desired state reliably.

## Quick Reference

- Main services: `dockerlabs` (app), `nginx`, `certbot`.
- Domains: `app1.otaviomiranda.com`, `app2.otaviomiranda.com`.
- Project dir on server: `/dockerlabsp2`.
- Deploy command (what GitHub Action effectively triggers):
  ```sh
  ssh github@34.61.67.116 'deploy.sh'
  ```
  (forced command handles the rest).
- Primary goals for any new work:
  1. Ensure infra is production-ready and reproducible.
  2. Keep teaching narrative coherent and beginner-friendly.
  3. Maintain security guarantees established in Video 2.
