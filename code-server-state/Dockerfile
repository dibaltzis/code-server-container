FROM codercom/code-server:latest

USER root

# Base utilities
RUN apt-get update && \
    apt-get install -y \
      curl \
      gpg \
      jq \
      ca-certificates \
      lsb-release \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Install GitHub CLI (gh)
# ----------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------
# Install Docker CLI (NOT daemon)
# ----------------------------
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------
# Optional LaTeX support
# ----------------------------
ARG INSTALL_LATEX=false
RUN if [ "$INSTALL_LATEX" = "true" ]; then \
      echo "Installing LaTeX toolchain..." && \
      apt-get update && \
      apt-get install -y \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        texlive-lang-greek \
        latexmk && \
      rm -rf /var/lib/apt/lists/* ; \
    else \
      echo "Skipping LaTeX installation"; \
    fi
    
# ----------------------------
# Match host docker group
# ----------------------------
ARG DOCKER_GID=972
RUN groupadd -g ${DOCKER_GID} docker || true && \
    usermod -aG docker coder

# Drop back to non-root
USER coder

