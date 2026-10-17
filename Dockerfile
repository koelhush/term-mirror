FROM ubuntu:22.04

LABEL maintainer="koelhush <oss@term-mirror.dev>"
LABEL description="TermMirror v1.0.0 - Persistent Dual-Screen (Terminal + Web) Mirroring Gateway for Docker"

ENV DEBIAN_FRONTEND=noninteractive
ENV WORKDIR=/workspace
ENV HOME=/home/sandbox
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 1. Install base build toolchain, SSH service, and Python aiohttp async gateway dependencies
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::https::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries \
    && apt-get update && apt-get install -y --no-install-recommends \
    locales \
    openssh-server \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    sudo \
    procps \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    python3-aiohttp \
    python-is-python3 \
    nodejs \
    npm \
    tar \
    gzip \
    iproute2 \
    net-tools \
    netcat-openbsd \
    vim \
    nano \
    jq \
    && echo "LANG=C.UTF-8\nLC_ALL=C.UTF-8" > /etc/default/locale \
    && rm -rf /var/lib/apt/lists/*

# 2. Create 1000:1000 sandbox user and configure passwordless sudo & SSH service
RUN groupadd -g 1000 sandbox \
    && useradd -m -u 1000 -g 1000 -s /bin/bash sandbox \
    && usermod -aG sudo sandbox \
    && echo "sandbox:sandbox" | chpasswd \
    && echo "root:sandbox" | chpasswd \
    && echo "sandbox ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sandbox \
    && echo "root ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/sandbox \
    && chmod 0440 /etc/sudoers.d/sandbox \
    && mkdir -p /var/run/sshd /root/.ssh /home/sandbox/.ssh /workspace \
    && chmod 700 /root/.ssh /home/sandbox/.ssh \
    && touch /home/sandbox/.sudo_as_admin_successful /home/sandbox/.hushlogin \
    && touch /root/.sudo_as_admin_successful /root/.hushlogin \
    && chown -R sandbox:sandbox /home/sandbox /workspace \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo "AuthorizedKeysFile %h/.ssh/authorized_keys /root/.ssh/authorized_keys" >> /etc/ssh/sshd_config \
    && echo "AcceptEnv WORKGITURL workgiturl WORK_GIT_URL" >> /etc/ssh/sshd_config \
    && echo "ClientAliveInterval 5" >> /etc/ssh/sshd_config \
    && echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config \
    && echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config \
    && echo "    StrictHostKeyChecking accept-new" >> /etc/ssh/ssh_config \
    && echo "    ServerAliveInterval 60" >> /etc/ssh/ssh_config \
    && git config --system --add safe.directory "*" \
    && git config --system user.name "TermMirror Agent" \
    && git config --system user.email "agent@term-mirror.local"

# 3. Deploy configuration templates and static web assets
RUN mkdir -p /opt/templates /opt/agentbox/web
COPY templates/AGENTS.md /opt/templates/AGENTS.md
COPY templates/mcp_config.json /opt/templates/mcp_config.json
COPY templates/settings.json /opt/templates/settings.json
COPY templates/web /opt/agentbox/web

# 4. Install single-master PTY byte-stream gateway (pty-hub) and attach client (pty-attach)
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/sandbox-login.sh /etc/profile.d/sandbox-login.sh
COPY scripts/sync-workgit.sh /usr/local/bin/sync-workgit
COPY scripts/pty_hub.py /usr/local/bin/pty_hub.py
COPY scripts/pty_attach.py /usr/local/bin/pty_attach.py
COPY scripts/sandbox-clean.sh /usr/local/bin/sandbox-clean

RUN chmod +x /entrypoint.sh \
    && chmod +x /etc/profile.d/sandbox-login.sh \
    && chmod +x /usr/local/bin/sync-workgit \
    && chmod +x /usr/local/bin/pty_hub.py \
    && chmod +x /usr/local/bin/pty_attach.py \
    && chmod +x /usr/local/bin/sandbox-clean \
    && mkdir -p /etc/entrypoint.d \
    && chmod 755 /etc/entrypoint.d \
    && echo "source /etc/profile.d/sandbox-login.sh" >> /root/.bashrc \
    && echo "source /etc/profile.d/sandbox-login.sh" >> /home/sandbox/.bashrc

# 5. Working directory and exposed ports (SSH: 22, WebUI: 7681)
WORKDIR /workspace
EXPOSE 22 7681

ENTRYPOINT ["/entrypoint.sh"]
