# Deploying Docker to a Linux Server

Now that we have the server, we can deploy our application.

```sh
# (Optional) If you want to change the default editor.
# Select the number corresponding to your preferred editor.
sudo update-alternatives --config editor
```

---

## The `.env.example` file

I'm moving my `.env` file to the project root. Since we only have a single
`.env` file, this isn't an issue.

This allows applications using our environment variables to load `.env`
automatically, saving us from adding `--env-file env/.env` to every command.

My `.env` was located in `env/.env`, so:

```sh
# Just move the .env to root
mv env/.env .
```

> **WARNING:** All commands using `--env-file env/.env` **MUST** remove that
> option or use `--env-file .env` instead.

The `.env` file is ignored in `.gitignore`, which means it won't be present when
we pull the code onto the server.

To address this, copy `.env` to `.env.example` and replace all sensitive values
with placeholders (usernames, passwords, secrets, and other sensitive data MUST
BE CHANGED).

Here is the `.env.example` I created:

```sh
# shellcheck disable=SC2034
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
POSTGRES_DB=db_name

# UNLESS POSTGRESQL CHANGES THIS DEFAULT, YOU DON'T NEED TO TOUCH
# THIS VARIABLE.
# https://hub.docker.com/_/postgres
PGDATA=/var/lib/postgresql/18/docker

DC_DOCKERFILE='Dockerfile'
DC_COMPOSE='compose.yaml'

# One of the most important configs is the name below. It is used across multiple
# configuration files. Ensure you use the same name as your main app container
# (tip: the container hosting your code).
DC_APP_CONTAINER_NAME='dockerlabs'
DC_APP_IMAGE_NAME='dockerlabs'

# Use this to set/check the environment where this code is running
# (development, production, staging, etc.).
# If set to `production`, the app will attempt to generate Let's Encrypt
# certificates.
CURRENT_ENV=development

# If you have more than one domain, use space separated values
# Example: "example.com domain.com"
DOMAINS="dock1.otaviomiranda.com dock2.otaviomiranda.com"
# This email is for Let's Encrypt notifications. It's recommended to use a
# valid email to avoid missing important updates.
EMAIL="luizomf@gmail.com"
```

---

## Configure git

Update the values as needed. You'll likely want to change the first three lines.

```sh
# These configs are per user

# This is the name for the git user. It doesn't need to be a real system user.
git config --global user.name "Luiz Otávio Miranda"
# This is the email for the user above.
git config --global user.email "otaviomiranda19@gmail.com"
# This is the project directory (/dockerlabs in my case).
git config --global --add safe.directory /dockerlabs

# You don't need to change the lines below unless you want to.
git config --global core.autocrlf input
git config --global core.eol lf
git config --global init.defaultbranch main
```

---

## Clone the repository

I'm creating the SSH Key Pair for your my own user. It needs to be able to
push/pull from our repository.

```sh
# ON THE SERVER
# Create the SSH Key Pair for YOUR USER.
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/repository -C "${USER}"

# Copy the PUBLIC KEY.
cat ~/.ssh/repository.pub

# ON GITHUB
# Click on your profile picture > Settings > SSH and GPG Keys >
# New SSH Key.
# Add a title, select `Authentication key` as the type, and paste the PUBLIC KEY.
# Click `Add SSH Key`.

# ON THE SERVER
# Open ~/.ssh/config
vim ~/.ssh/config

# Add the following:
Host github.com:
  HostName github.com
  User git
  Port 22
  IdentityFile ~/.ssh/repository

# Run this command to add github.com to your user's known_hosts
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

We already created the project folder, but in case you didn't, let's ensure the
permissions are correct:

```sh
mkdir /dockerlabs
sudo chmod -R 775 /dockerlabs
sudo groupadd project --gid 1020
sudo usermod -aG project $USER
sudo chmod g+s /dockerlabs
```

Now we can clone the repository:

```sh
cd /dockerlabs
git clone REPOSITORY_SSH_URL . # <- THE DOT IS IMPORTANT
```

The dot at the end ensures `git` doesn't create a new directory (since we
already have one).

---

## The `.env.example` to `.env` (Yes, again)

Now that you're on the server, copy `.env.example` to `.env`.

```sh
cd /dockerlabs
cp .env.example .env
# Open it in your preferred editor and update the placeholder values.
vim .env
# Keep `CURRENT_ENV` as `development` for testing.
# Seriously, we need to test `development` first.
```

---

## Generate the dummy SSL certificates

I created a bash script to handle this. Just run it. Keep
`CURRENT_ENV=development`, so if anything goes wrong, we won't attempt to
generate Let's Encrypt SSL certificates yet.

```sh
sudo /dockerlabs/scripts/bootstrap.sh
```

If there are no errors, you should be able to access the server in your browser.
It will likely show a warning that your site is insecure. This is because we
haven't generated the real SSL certificates yet.

Let's test other things first. I prefer to generate certificates only when I'm
confident everything else is working.

---

## Test the Docker build

Finally, we can test our build. Again, keep `CURRENT_ENV=development` to avoid
premature SSL generation (repeating this because I know some of you skip
instructions).

**IMPORTANT**: my bash script already builds the system. If everything is
working, you don't have to do it again.

```sh
# Run the build
sudo docker compose up -d --build
# Check with:
docker ps
# If all containers are up without restarting, that's OK.
```

---

## Generate Let's Encrypt SSL certificates

Now that everything is working, we can attempt to generate our real SSL
certificates.

Open `.env` and double-check everything (domains, email, etc.). Then, change
`CURRENT_ENV` to `production`.

```sh
vim /dockerlabs/.env

# Check everything and change:
CURRENT_ENV=production
```

Now run that script again:

```sh
sudo /dockerlabs/scripts/bootstrap.sh
```

No errors for me, but errors might occur during SSL certificate generation.

A common problem is:

If NGINX fails to start before Certbot generates the SSL certificates, Certbot
can't challenge NGINX to verify our domain identity. Certbot uses a specific
NGINX server block I created for this verification on port 80 (HTTP).

If Certbot fails because NGINX failed, no certificates are created.

Now NGINX won't run at all, as we have neither dummy nor real certificates.

If this happens, change `CURRENT_ENV` back to `development` and run
`/dockerlabs/scripts/bootstrap.sh` again.

If that works, switch `CURRENT_ENV` back to `production` and retry.

Check the logs to identify the error.

You can use these commands to check logs:

```sh
docker logs nginx
docker logs certbot
docker logs container-name
docker logs nginx -f # <- follows output (like tail -f)
```

---

## Create a `deploy` user for the GitHub Action

Since the last video, I've changed my mind about some ideas I had. I want the
`github` user to have the fewest permissions possible.

The reason is that the **GitHub Action** will use a single SSH Private Key,
allowing the `github` user to execute these commands:

- `cd /dockerlabs`
- `git pull`
- `docker compose up -d --build`

I don't want to create rules for each of these commands, so I'll create a single
bash script and restrict the `github` user to running only that script.

```sh
# Delete the user created in the last video and confirm.
sudo userdel github -r
cat /etc/passwd | grep github # nothing
cat /etc/group | grep github # nothing

# Create a new user.
sudo groupadd github --gid 1010
sudo useradd github -m -s /bin/bash --uid 1010 --gid 1010

sudo mkdir -p /home/github/.ssh
sudo touch /home/github/.ssh/authorized_keys

# Those are the correct .ssh directory correct permissions
# We may not have all those files. That's OK!
sudo chmod 700 /home/github/.ssh
sudo chmod 600 /home/github/.ssh/id_*
sudo chmod 600 /home/github/.ssh/{authorized_keys,config,known_hosts}
sudo chmod 644 /home/github/.ssh/*.pub
sudo chown -R github:github /home/github/.ssh

# Add it to the project group as well.
sudo usermod -aG project github

# Change the github user's password (we'll remove it later).
sudo passwd github
# Login
su github
cd ~ # go to home

# This user needs access to our repository.
# So, let's create an SSH Key Pair for the repository.
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/repository -C "github"

# Open ~/.ssh/config
vim ~/.ssh/config

# Add the following configuration:
Host github.com
  HostName github.com
  User git
  Port 22
  IdentityFile ~/.ssh/repository

# Copy the public key.
cat ~/.ssh/repository.pub

# ON GITHUB
# Tip: While you're configuring GitHub, reboot the server.
# Click on your profile picture > Settings > SSH and GPG Keys >
# New SSH Key.
# Add a title, select `Authentication key` as the type, and paste the PUBLIC KEY
# value you copied earlier.
# Click the `Add SSH Key` button.

# ON THE SERVER
# After configuring GitHub, run the following to add its URL to `known_hosts`
# for our github user.
ssh-keyscan github.com >> ~/.ssh/known_hosts

# If you want to confirm this user can pull from the repo, simply clone your
# project using SSH temporarily, then remove it (we'll do this with our own
# user later).
git clone git@github.com:YOUR_GH_USER/YOUR_REPO.git TEMP
rm -Rf TEMP/
# If you don't see any errors, it's ready!

# Since we're here, let configure the git for this user
# These configs are per user

# This is the name for the git user. It doesn't need to be a real system user.
git config --global user.name "GitHub Action"
# This is the email for the user above.
git config --global user.email "github@action.com"
# This is the project directory (/dockerlabs in my case).
git config --global --add safe.directory /dockerlabs

# You don't need to change the lines below unless you want to.
git config --global core.autocrlf input
git config --global core.eol lf
git config --global init.defaultbranch main

# We'll return later to lock this user down as tight as possible, so hold on.
```

---

## Configure SSH Keys for the GitHub Action

Now we need to create SSH Keys for the GitHub user in a slightly unusual way.
The **PRIVATE KEY** is for the GitHub Action, so it will be stored on GitHub.

Since we are connecting to this server from a GitHub runner, the most secure
method is using SSH Keys (rather than passwords).

That's why we created the `github` user. We want this user to have the absolute
minimum privileges.

```sh
# ON YOUR LOCAL COMPUTER (Not the server, nor GitHub).
# Generate a temporary SSH KEY pair (I'll help you delete it later).
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/delete-me -C "github"

# Copy the PRIVATE KEY.
# You'll paste it into GitHub Actions (I'll guide you in the comments).
cat ~/.ssh/delete-me | pbcopy

# ON GITHUB REPOSITORY (The project code on GitHub):
# In the Settings tab, go to:
# Secrets and Variables > Actions > New Repository Secret
# The field name is KEY (if you change this, you'll need to update all subsequent commands).
# The secret is the value you copied (the full private key string).
#
# Now add these other keys and values. We'll use them shortly.
# Key: USER=github
# Key: HOST=SERVER_IP_OR_HOST (
# Key: PORT=22
#
# To confirm, the keys are: KEY, USER, HOST, and PORT.
#
# P.S.: Don't worry, once set, no one (including you) can see these values.
#

# ON YOUR LOCAL COMPUTER (again)
# Copy the PUBLIC KEY.
# It will be used on the server.
cat ~/.ssh/delete-me.pub

# ON THE SERVER (Where we are deploying the application)
# Open the authorized_keys of the github user.
# Caution: when using root, ~ ($HOME) points to /root/. You might add these to
# the wrong user.
# Use the absolute path to ensure you're editing the correct file for the
# correct user.
sudo vim /home/github/.ssh/authorized_keys
# Paste it.
# Replace PUBLIC_KEY with the public key value you copied earlier.
# I know it's a long line, but that's how it works. And yes, it MUST BE a
# single line.
# I'll explain each part of this line later. But trust me, we're locking the
# github user down tight.
command="/usr/local/bin/deploy.sh",restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty PUBLIC_KEY github

# To ensure everything works perfectly, reboot the server.
# It's not strictly necessary, but it can avoid headaches (e.g., refreshing
# tmux sessions, reloading ssh config, etc.).

# When you're done, delete the keys.
# I told you I'd help you clean up.
rm ~/.ssh/{delete-me,delete-me.pub}
```

---

## SSH Keys and Security

Let me explain that long line we added to `/home/github/.ssh/authorized_keys`
earlier.

```sh
# I'm breaking lines here for readability, but the OpenSSH authorized_keys
# format requires each public key (including options) to be a single,
# continuous line.
# So no, we can't use this nice formatting in the actual file.
command="/usr/local/bin/deploy.sh", # <- The only command github can execute
restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty # <- See below
PUBLIC_KEY # <- The public key (assuming you're using the value you copied)
github # <- This is a comment, usually used to identify the user
```

Now to the other restrictions.

### `restrict`

This is a macro that implies a "default deny" posture for that key. It
effectively disables common dangerous capabilities unless you explicitly allow
them.

### `no-port-forwarding`

Disables `-L`, `-R`, `-D` tunnels. If the key leaks, attackers can't use your
server as a pivot to access internal services (DBs, Redis, metadata endpoints,
etc).

### `no-agent-forwarding`

Disables SSH agent forwarding. Agent forwarding could otherwise be abused to
authenticate "**as you**" (or as `github`) to other machines.

### `no-X11-forwarding`

Disables X11 forwarding. Mostly irrelevant on servers, but let's disable it
anyway 🙉 (I don't care, just keep it).

### `no-pty`

No interactive TTY allocation prevents a "real shell experience". **Not a full
blocker on its own** (you can still run non-interactive commands), but it
reduces the attack surface. The `github` user won't be able to "login" like a
normal user.

### `command="..."` - This is beautiful 💅

To me, this is the most important one.

With this, SSH will **ignore whatever command the client tries to run** and will
always execute `/usr/local/bin/deploy.sh` instead. Even if the user types
`echo 123`, it will execute what we configured it to 😈.

So if someone steals the key and tries something like this:

```sh
# Attacker
ssh deploy@server 'rm -rf /'
# The server
ssh deploy@server 'deploy.sh' # 😉
```

The server still runs `deploy.sh`, not `rm -rf /`.

That's the main security win.

---

## Create the deploy script

```sh
# Create the file.
sudo touch /usr/local/bin/deploy.sh
# Open in vim.
sudo vim /usr/local/bin/deploy.sh
```

Here are the commands I want to run. Ensure you update `APP_DIR` and `BRANCH`.

```bash
#!/usr/bin/env bash

################################################################################
# Author: Luiz Otávio Miranda <luizomf@gmail.com>
# Date: 2025-12-30
# License: MIT
################################################################################

set -Eeuo pipefail

catch_errors() {
  local rc=$?
  printf 'ERROR: line=%s rc=%s cmd=%q\n' \
    "$LINENO" "$rc" "$BASH_COMMAND" >&2
  exit "$rc"
}

trap catch_errors ERR

APP_DIR="/dockerlabs"
BRANCH="main"

cd "$APP_DIR"

# Safety: Ensure we are in the correct repo.
test -d .git

# Pull and deploy.
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

# This sudo bothers me, so I'm restricting this command for the github user in
# sudoers (more on that in a minute).
sudo docker compose up -d --build

# Noice 😚!!!
echo "OK: deployed $(git rev-parse --short HEAD)"
```

Also, ensure this file is owned by `root` and that others can only read and
execute it.

You know this is the only command `github` can run. So, if malicious code or a
user edits this file to do something unexpected, we're in trouble.

I'll take additional steps later to ensure `github` can't run anything other
than what I want. Better safe than sorry.

```bash
sudo chown root:root /usr/local/bin/deploy.sh
sudo chmod +x /usr/local/bin/deploy.sh
sudo chmod 755 /usr/local/bin/deploy.sh
```

Since this file is in `/usr/local/bin` (which is in your `$PATH`), you can run
it by name, simply as `deploy.sh` (BUT DON'T RUN IT YET).

---

## sudoers and visudo (Locking the github user)

Remember that `sudo` bothering me earlier? Now let's ensure the `github` user
can't execute anything other than what we explicitly allow.

### But first... a word of caution

Let me start by saying this loud and clear: **THIS IS NOT SAFE**.

We are allowing the `github` user to elevate its privileges via `sudo` for one
specific command. However, there are commands, and then there are **commands**.

The problem lies in our trade-off. We are building the Docker image **on the
server for convenience**, which is bad practice. The server should only pull
images after they've been tested in CI. Since we don't have a CI pipeline, we
can't do that here. Besides, that's way beyond the scope of this tutorial
series.

Nevertheless, if an attacker modifies the `Dockerfile` or `compose.yaml`, they
could execute whatever they like.

Because `docker compose up --build` can:

- Execute arbitrary commands in Dockerfile
- Mount host directories into containers
- Run privileged containers
- Modify the host filesystem indirectly

This means:

- If the repository is compromised
- Or `compose.yaml` is maliciously modified
- Or build steps are altered

An attacker can effectively gain root access to the host.

If you're uncomfortable with this approach, you should:

- Build images in CI (not on the server)
- Push immutable images to a registry
- On the server, only pull immutable images

If you want to know more about `sudo` and `sudoers`, I covered it 10 years ago
in this video:

- [Su, Sudo e Sudoers no Linux (Portuguese)](https://youtu.be/aTbEhjvlmxg?si=YkH9wAN59waTHuyx)

### Now, to the commands

```sh
# First, let's remove the password we added earlier for testing.
# Lock the account (remove password).
sudo usermod -L github

# Let's configure the sudoers file.
# Listen up: DO NOT EDIT /etc/sudoers directly (as I emphasized in the video).
# Use this instead, it's safer:
sudo visudo -f /etc/sudoers.d/github
# Add these lines, save the file, and close the editor.
Cmnd_Alias DOCKER_COMPOSE_UP = /usr/bin/docker compose up -d --build
github ALL=(root) NOPASSWD: DOCKER_COMPOSE_UP
# What do these lines do?
# They allow the github user to execute `docker compose up -d --build`
# (precisely) as root (with sudo), without a password.
# This feels dangerous, right? Please review the trade-offs mentioned above.

# OPTIONAL FOR TESTING AND FOR NERDS
# If you want to test, do this instead.
Cmnd_Alias DOCKER_COMPOSE_HELP = /usr/bin/docker compose --help
github ALL=(root) NOPASSWD: DOCKER_COMPOSE_HELP
# This allows github to run:
# - sudo docker compose --help    # allowed
#
# But it won't be able to execute any other command via sudo:
# - sudo docker ps                # denied
# - sudo ls /root                 # denied

# Now stop playing around and add the first command I gave you.
```

---

## The actual GitHub Action

This goes in your project. This is the GitHub Action that will trigger when we
push to the `main` branch.

```sh
# In your codebase, create the file .github/workflows/deploy.yaml
# This is our GitHub Action.
# I'm pinning a specific commit hash for security reasons (we don't want it to
# change unexpectedly).
name: Simple deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to server on push to main
        uses: appleboy/ssh-action@23bd972bfcf52bf00cbb7f7f62b2bb06c2efa5b4
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USER }}
          key: ${{ secrets.KEY }}
          port: ${{ secrets.PORT }}
          script: deploy.sh
```

The `script` line is essentially documentation. As I said, it doesn't matter
what the user tries to run.

When we push code to the `main` branch, this action triggers. It uses a specific
version of `appleboy/ssh-action` for security.

The values for `HOST`, `USER`, `KEY`, and `PORT` correspond to those we created
earlier. I hope you didn't change the key names.

---

## Now testing the GitHub Action

You can push something to the `main` branch of your repository and check the
`Actions` tab on GitHub to see what happens.

If it passes, you've configured everything correctly. If it fails, the error
usually appears directly in the action logs.

Common issues include permissions, SSH keys, `known_hosts`, branch names, etc.

---

## Last check

**IMPORTANT**: my bash script already builds the system. If everything is
working, you don't have to do it again.

Check if all containers are running:

```sh
docker ps
```

You should see four containers: `your-app-1`, `your-app-2`, `certbot`, and
`nginx`.

If you don't see all of them, run the following and then reboot:

```sh
cd /dockerlabs
docker compose up -d --build --force-recreate --remove-orphans
# Wait for it to finish and check again. When all four are up, reboot.
sudo reboot
# The server takes a moment to reboot. When it's back, run:
docker ps # Now all four should be running. Enjoy!
```

---
