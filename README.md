# Code-Server Self-Hosted Development Environment

This repository provides a **clean, reproducible, browser-based VS Code ([code-server](https://github.com/coder/code-server)) setup** with:

- Persistent extensions and settings
- GitHub authentication via GitHub CLI (`gh`)
- Gitea authentication via SSH
- Docker access from inside code-server
- Clean separation between **projects** and **platform state**
- No dependency on browser local storage or VS Code profiles

This setup was built with **easy reproducibility in mind**: by backing up or syncing the `code-server-state/` directory, all editor settings, extensions, and authentication state are preserved and can be restored on any host.

---

## Directory Layout

```
code-projects/
code-server-state/
```

### `code-projects/`
- Contains **only the source code** of future projects, a main folder structure

### `code-server-state/`
- Contains the **entire development platform state**
- Includes **editor settings, extensions, caches, and authentication data**
- Holds **SSH keys, Git credentials, GitHub CLI auth, and code-server config**
- **Must never be committed to a public repository**

This directory is the **single source of truth** for the development environment.

Backing up or syncing this folder preserves:
- VS Code settings
- Installed extensions
- Git identity
- GitHub (`gh`) authentication
- SSH keys for Git/Gitea
- code-server configuration

Restoring this directory restores the full environment exactly as it was.

### Repository Structure
```
.
├── Dockerfile                  # Builds the base code-server image
├── Dockerfile_local            # # Builds the local code-server image with DOCKER_GID for docker access
├── docker-compose.basebuild.yml  # Docker compose for base image
├── docker-compose.yml          # Main deployment definition
├── entrypoint.d/               # Startup scripts executed inside the container
│   ├── 10-install-extensions.sh  # Installs VS Code extensions from extensions.txt
│   └── 20-copilot.sh             # Installs and patches GitHub Copilot for code-server
├── extensions.txt              # List of VS Code extensions to auto-install
├── config/
│   └── code-server/            # code-server configuration directory
│       └── config.yaml         # code-server settings (auth, bind address, certs, etc.)
├── data/                       # Persistent code-server user data (state, cache)
├── ssh/                        # Location of SSH keys for Git/Gitea/GitHub access
├── gh/                         # GitHub CLI configuration and authentication
├── git/
│   └── .gitconfig              # Global Git identity and defaults
├── certs/                      # TLS certificates for HTTPS
│   ├── server.crt              # TLS certificate
│   └── server.key              # TLS private key
└── README.md                   # Project documentation

```
---

## Setup Instructions

### Image Architecture Model (Base + Local Wrapper)
This repository uses a **two-layer image model**:

- A **base image** that provides the full development platform and is safe to push to a registry
- A **local wrapper image** that performs host-specific integration (such as matching the Docker group GID) and may include additional local-only packages

This keeps the platform portable while allowing clean, explicit host integration for local use.


### 1. Clone the Repository

```bash
git clone https://github.com/dibaltzis/code-server-container.git
cd code-server-state
```

---

### 2. Add TLS Certificates

Place your TLS certificate files here:

```
/code-server-state/certs/server.crt
/code-server-state/certs/server.key
```

These are referenced by `config/code-server/config.yaml`.

---

### 3. Configure Extensions

Edit:

```
extensions.txt
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

```
docker compose -f docker-compose.basebuild.yml build
```

> **Optional build features**
>
> - If you don’t need the LaTeX packages installed, set INSTALL_LATEX in `docker-compose.basebuild.yml` to `false`.
>
> - If you don’t need Ansible installed, set INSTALL_ANSIBLE in `docker-compose.basebuild.yml` to `false`.

### 5. Prepare for the Local Image (Host Integration)

On the **host**, determine the Docker group GID:

```bash
getent group docker
```

Example output:

```
docker:x:972:youruser
```

Take note of the GID (example: `972`).

Update:
- `docker-compose.yml`

Ensure the value of `DOCKER_GID` matches the host.

This allows the `coder` user inside the container to access `/var/run/docker.sock`.

> At this point you can also add any needed local-only packages inside `Dockerfile_local`.
---

### 6. Build and Deploy

From inside `code-server-state/`:


Build the local wrapper image:
```
docker compose -f docker-compose.yml build
```

Deploy: 
```
docker compose -f docker-compose.yml up -d
```

Then open:

```
https://<host>:8443
```

---

### 7. Verify Docker Access (Inside Code-Server)

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
