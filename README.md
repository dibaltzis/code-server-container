# Code-Server Self-Hosted Development Environment
A portable, reproducible browser-based development environment with optional reverse proxy and authentication.

This repository provides a **clean, reproducible, browser-based VS Code ([code-server](https://github.com/coder/code-server)) setup** with:

- Persistent extensions and settings
- GitHub authentication via GitHub CLI (`gh`)
- Gitea authentication via SSH
- Docker access from inside code-server
- Clean separation between **projects** and **platform state**
- No dependency on browser local storage or VS Code profiles

This setup was built with **reproducibility as the primary goal** by backing up or syncing the `code-server-state/` directory, all editor settings, extensions, and authentication state are preserved and can be restored on any host.

---

## Directory Layout

code-projects/
code-server-state/
infra/

### `code-projects/`
- Contains **only your projects source code**
- Acts as your working directory inside code-server (`/workspace/projects`)
- Completely independent from the development environment itself

---

### `code-server-state/`
- Contains the **entire state of the development environment**
- Includes **editor settings, extensions, caches, and authentication data**
- Holds **SSH keys, Git credentials, GitHub CLI auth, and code-server config**
- **Must never be committed to a public repository, as it contains sensitive data**

This directory is the **single source of truth** for the development environment.

Backing up or syncing this folder preserves:
- VS Code settings
- Installed extensions
- Git identity
- GitHub (`gh`) authentication
- SSH keys for Git/Gitea
- code-server configuration

Restoring this directory restores the full environment exactly as it was.

---

### `infra/`
- Contains all **infrastructure-related configuration**
- Includes Docker setup, reverse proxy configuration, and supporting files
- Can be modified or replaced without affecting your development state

---

## Repository Structure
```
code-server-container/
├── code-projects/                  # Your actual development projects
├── code-server-state/              # Persistent development environment state
│   ├── certs/                      # TLS certificates (used in direct mode)
│   ├── config/
│   │   └── code-server/
│   │       └── config.yaml         # code-server configuration
│   ├── data/                       # code-server data (extensions, cache, etc.)
│   ├── gh/                         # GitHub CLI authentication
│   ├── git/
│   │   └── .gitconfig              # Global Git configuration
│   └── ssh/                        # SSH keys for Git/Gitea/GitHub
│
├── infra/
│   ├── docker/                     # All Docker-related files
│   │   ├── docker-compose.basebuild.yml  # Base image build definition
│   │   ├── docker-compose.yml            # Main deployment
│   │   ├── Dockerfile                   # Base image
│   │   ├── Dockerfile_local             # Local wrapper (Docker socket access)
│   │   ├── entrypoint.d/                # Container startup scripts
│   │   │   ├── 10-install-extensions.sh
│   │   │   └── 20-copilot.sh
│   │   ├── extensions.txt               # Extensions to install
│   │   └── push_to_local_registry.sh
│   │
│   ├── nginx/                      # Generated nginx + Authelia configuration
│   └── proxy.config.example.yml          # Example config for reverse proxy setup
│
└── README.md
```
---

## Setup Instructions

### Image Architecture Model (Base + Local Wrapper)
This repository uses a **two-layer image model**:

- A **base image** that provides the full development platform and is safe to push to a registry
- A **local wrapper image** that performs host-specific integration (such as matching the Docker group GID) and may include additional local-only packages

This keeps the platform portable while allowing clean, explicit host integration for local use.

---


### 1. Clone the Repository

```bash
git clone https://github.com/dibaltzis/code-server-container.git
cd code-server-container
```

---

### 2. (Optional) Add TLS Certificates (Direct Mode Only)

If you plan to run **code-server directly (without reverse proxy)**, place your TLS certificate files here:

```
code-server-state/certs/server.crt
code-server-state/certs/server.key
```

These are referenced by:

code-server-state/config/code-server/config.yaml

If you plan to use the **reverse proxy setup**, you can skip this step.

---

### 3. Configure Extensions

Edit:

```
infra/docker/extensions.txt
```

Add one extension ID per line.  

Example:

```
ms-python.python
ms-python.debugpy
ms-python.vscode-python-envs
ms-azuretools.vscode-docker
```

Extensions are installed automatically at container startup.

---

### 4. Build the base image 

```bash
cd infra/docker 
docker compose -f docker-compose.basebuild.yml build
```

> Optional build features:
>- Disable LaTeX by setting INSTALL_LATEX=false
>- Disable Ansible by setting INSTALL_ANSIBLE=false

### 5. Prepare for the Local Image (Host Integration)

On the **host**, determine the Docker group GID:

```bash
getent group docker
```

Example output:

```
docker:x:972:youruser
```

Update the value of DOCKER_GID in:

- `infra/docker/docker-compose.yml`

This allows the `coder` user inside the container to access `/var/run/docker.sock`.

> You can also add any local-only packages in Dockerfile_local

---

### 6. Build and Deploy

```bash
cd infra/docker
# build
docker compose -f docker-compose.yml build
# deploy
docker compose -f docker-compose.yml up -d
```

--- 
### 7. Access
Then open:

```
https://<host>:8443
```

---

### 8. Verify Docker Access (Inside Code-Server)

Open a terminal in code-server and run:

```bash
groups
```

Expected output includes:

```
docker
```

Then test:

```bash
docker ps
```

You should see host containers listed.

---

## Optional: Reverse Proxy + Authentication

This setup places nginx + Authelia in front of code-server, providing:

- HTTPS via nginx
- Authentication via Authelia
- Clean subdomain access (e.g. `code.<ip>.nip.io`)

---

### 1. Update code-server Configuration

Edit:

`code-server-state/config/code-server/config.yaml`

Set:
```
bind-addr: 0.0.0.0:8080  
auth: none  
cert: false  
```
---

### 2. Configure Proxy

Edit:

`infra/example.config.yml`

Update the following fields:
- username
- password
- email

The rest of the configuration is preconfigured.

---

### 3. Generate nginx + Authelia Configuration

```bash
docker run --rm \
  -v $(pwd)/infra/proxy.config.example.yml:/app/config.yml \
  -v $(pwd)/infra/nginx:/app/nginx \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e HOST_NGINX_PATH=$(pwd)/infra/nginx \
  ghcr.io/dibaltzis/tools-collection/proxy-gen:latest
```
---

### 4. Start with Proxy Enabled

```bash
cd infra/docker  
docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d  
```
---

### 5. Access via Domain

https://code.<your-ip>.nip.io/?folder=/workspace/projects

---

### Notes

- In this mode, nginx handles TLS (not code-server)
- Authentication is handled by Authelia
- For more details, see the proxy-gen project [docs](https://github.com/dibaltzis/tools-collection/tree/main/tools/proxy-gen)



## Maintenance

### Updating code-server

The base image uses the latest upstream `code-server` image. To update to a newer version, simply rebuild and redeploy the containers.

From `infra/docker`:
```bash 
# Rebuild the base image (pulls latest code-server)
docker compose -f docker-compose.basebuild.yml build  

# Rebuild the local image (extends the updated base image)
docker compose -f docker-compose.yml build  

# Redeploy the container
docker compose -f docker-compose.yml up -d 
```
Your existing environment (code-server-state/) is preserved.

## Authentication

### GitHub Authentication (Persistent)

Inside the code-server terminal:

```bash
gh auth login
```

Choose:
- GitHub.com
- HTTPS
- Login with a web browser

Verify:

```bash
gh auth status
```

Credentials are stored in:

```
code-server-state/gh/
```

They persist across browser clears and container restarts.

---

### Git Configuration (Optional)

Modify `code-server-state/git/.gitconfig` to:
```ini
[user]
  name = Your Name
  email = you@example.com
```

---

### Gitea Authentication (SSH)

Generate an SSH key inside code-server:

```bash
ssh-keygen -t ed25519 -C "code-server@gitea"
```

Add the public key (`~/.ssh/id_ed25519.pub`) to Gitea:

```
User Settings → SSH / GPG Keys
```

> **Important:** Gitea SSH often runs on a non‑standard port (e.g. `222`).

Recommended SSH config (`~/.ssh/config`) for that case:

```ssh
Host gitea
  HostName <gitea-host>
  Port 222
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

SSH keys persist across browser clears and container restarts.
