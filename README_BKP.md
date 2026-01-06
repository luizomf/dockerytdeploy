# Docker

I'll put some of my annotations in this README so I can remember it later.

---

## Useful commands

Some commando we use all the time in docker.

```sh
# creates and run a container (--rm also remove it after run)
docker run image
# create and run a container with a proper name
docker run --name container_name image
# shows running containers
docker ps # (-a show all including stopped containers)
# stops container
docker stop container_id # docker stop $(docker ps -a -q)
# deletes the container
docker rm container_id # docker rm $(docker ps -a -q)
# builds a container from your image
docker build -t container_id -f ./dockerfile/path ./context/path
# shows all docker networks
docker network ls # docker network rm $(docker network ls -a -q)
# shows volumes
docker volume ls # docker volume rm $(docker volume ls -a -q)
# enters the container shell (it need to be started and its good for live checking)
docker exec -it container_id bash
# creates a container based on the image and enters its shell using bash
docker run --rm -it image:tag bash
# show logs for a container
docker logs container_id
# shows images
docker image ls # docker image rm $(docker image ls -a -q)
# builds the image, starts all the containers in compose.yaml with watch mode
docker compose -f path/to/compose.yaml up --build --watch
```

## Add ssh-keys

```sh
sudo apt update
sudo apt upgrade -y

ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519_gcp -C "luizotavio"
vim ~/.ssh/config

Host *
  IgnoreUnknown AddKeysToAgent,UseKeychain
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519_gcp
  User luizotavio
  Port 22

sudo vim /etc/ssh/sshd_config


PubkeyAuthentication yes # só com chaves
PasswordAuthentication no # sem senha
KbdInteractiveAuthentication no # tipo de 2FA
ChallengeResponseAuthentication no
PermitRootLogin no # nunca como root
PermitEmptyPasswords no # sem senha vazia
UsePAM yes # o método de autenticação

# Quem pode entrar
# Eu acho isso meio demais, mas daria para fazer
AllowUsers luiz
AllowGroups luiz


# Gerar certificado local
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout data/certbot/live/localhost/privkey.pem -out data/certbot/live/localhost/fullchain.pem -subj "/CN=localhost"

https://github.com/certbot/certbot/blob/main/certbot-nginx/src/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
https://github.com/certbot/certbot/blob/main/certbot/src/certbot/ssl-dhparams.pem
```

Para a github action usando @appleboy/ssh-action:1.2.4 precisamos gerar uma
chave privada para a action. Ela terá que agir como um usuário do sistema.

```sh
# -----------------------------------------------------------
# 1. NA SUA MÁQUINA LOCAL
# -----------------------------------------------------------
# Gerar a chave (Perfeito, ed25519 é o padrão ouro hoje)
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/deploy_key -C "github-actions"

# Copia a chave pública para a área de transferência (para colar no server)
cat ~/.ssh/deploy_key.pub | pbcopy

# Copia a chave privada para a área de transferência (para colar no GitHub Secrets)
# cat ~/.ssh/deploy_key | pbcopy


# -----------------------------------------------------------
# 2. NO SERVIDOR (Como root ou sudo)
# -----------------------------------------------------------

# Cria o grupo que vai permitir vocês dois mexerem na pasta
sudo groupadd dockerlabs --gid 1004

sudo groupadd github --gid 1005
sudo useradd github --create-home --shell /bin/bash --uid 1005

sudo groupadd certbot --gid 1010
sudo useradd certbot --create-home --shell /bin/bash --uid 1010

# --- A MÁGICA DAS PERMISSÕES COMPARTILHADAS ---

# Move o projeto para a raiz (sai da home do usuário pessoal)
sudo mv /home/luizotavio/dockerlabs/

# Define que a pasta pertence a esse grupo
sudo chgrp -R dockerlabs /dockerlabs

# Adiciona os usuários ao grupo
sudo usermod -aG dockerlabs luizotavio
sudo usermod -aG dockerlabs github
sudo usermod -aG dockerlabs certbot

# Adiciona o usuário github ao grupo docker (para poder dar restart nos containers)
sudo usermod --groups docker,dockerlabs,certbot github
sudo usermod --groups docker,dockerlabs,certbot certbot
sudo usermod --groups docker,dockerlabs,certbot luizotavio

# [IMPORTANTE] Ajusta as permissões da pasta:
# 1. Dá permissão pro Grupo ler e escrever (chmod 775 ou g+w)
sudo chmod -R 775 /dockerlabs

# 2. Ativa o "SetGID" (g+s). Isso garante que arquivos novos criados pelo github
# mantenham o grupo 'dockerlabs', senão vira bagunça de permissão depois.
sudo chmod g+s /dockerlabs

# [IMPORTANTE] Avisa ao Git que essa pasta é segura (senão ele bloqueia por troca de dono)
# Rodar isso como o usuário github ou globalmente
sudo git config --system --add safe.directory /dockerlabs

# --- CONFIGURANDO O SSH DO ROBÔ ---

# Cria a pasta .ssh
sudo mkdir -p /home/github/.ssh/

# Cria o arquivo authorized_keys
sudo touch /home/github/.ssh/authorized_keys

# Cola a chave pública (aqui você usa o editor nano/vim na aula)
# nano /home/github/.ssh/authorized_keys

# Ajusta as permissões do SSH (O SSH é chato, se estiver errado ele não loga)
sudo chown -R github:github /home/github/.ssh/
sudo chmod 700 /home/github/.ssh/
sudo chmod 600 /home/github/.ssh/authorized_keys # O arquivo precisa ser restrito!

# -----------------------------------------------------------
# 3. TESTE FINAL (Do seu PC)
# -----------------------------------------------------------
ssh github@IP_DO_SERVER -i ~/.ssh/deploy_key

# Se logar, teste se consegue escrever na pasta:
cd /dockerlabs
touch teste_permissions.txt
ls -l teste_permissions.txt
# Se o grupo do arquivo for "dockerlabs", parabéns! Configuração Pro.
```

fail2ban

Se você mesmo vai manter o server online, melhor configurar algo que bane
tentativas e um firewall. O google já tem, mas vamos garantir.

```sh
sudo apt update && sudo apt install -y fail2ban
sudo apt install -y ufw

# DEFINE O PADRÃO: Nega tudo que entra, Libera tudo que sai.
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH liberado na porta 22
sudo ufw allow ssh

# Se for liberar um CDN e deixar o resto tudo bloqueado (recomendado).
# Seque um exemplo:
# Esse script baixa a lista oficial de IPs da Cloudflare e cria as regras
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    sudo ufw allow proto tcp from $ip to any port 80,443 comment 'Cloudflare IPv4'
done

# Faz o mesmo para IPv6 se seu server tiver
for ip in $(curl -s https://www.cloudflare.com/ips-v6); do
    sudo ufw allow proto tcp from $ip to any port 80,443 comment 'Cloudflare IPv6'
done

# Allow necessary ports
sudo ufw allow OpenSSH    # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS

# Enable UFW
sudo ufw enable

# Check UFW status
sudo ufw status

# Vai perguntar "Command may disrupt existing ssh connections".
# Como liberamos o SSH no passo 3, pode dar 'y'.
sudo ufw enable

# CONFERE O RESULTADO
sudo ufw status verbose
```

```sh
# Install Fail2Ban
sudo apt install fail2ban

# Create a local configuration file
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit Fail2Ban configuration for SSH
sudo nano /etc/fail2ban/jail.local
# Ensure the following lines are set:
# [sshd]
# enabled = true
# port = 22 # Change this if you've modified your SSH port.
# maxretry = 5
# bantime = 3600

# Restart Fail2Ban service
sudo systemctl restart fail2ban

# Check Fail2Ban status
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

```
certbot certonly \
  --webroot -w /var/www/certbot \
  --cert-name all_domains \
  --expand \
  -d example.com \
  -d another.com \
  -d etc.com \
  -d novo.com
```

## Passos no servidor

1. Clonar o repositório
2. Copiar o .env.example `cp env/.env.example env/.env`
3. Ajuste o `.env` para `development`
4. Execute `./scripts/letsencrypt.sh`
5. Faça a build do docker
6. Faça um teste mesmo com o certificado auto assinado
7. Ajuste o `.env` para `production`

## Problema de permissões no git

```sh
# Mudamos para o gripo que criamos antes
sudo chmod -Rf g+rws .git
sudo chown -Rf :dockerlabs .git
sudo chmod -Rf g+s .git
```

---
