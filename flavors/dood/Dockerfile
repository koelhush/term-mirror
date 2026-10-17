FROM term-mirror:latest

LABEL description="TermMirror with Docker CLI (Docker-outside-of-Docker) support"

USER root

# Install docker.io client
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker sandbox 2>/dev/null || true

# Inject flavor rules and startup hook
COPY templates/AGENTS_EXTRA.md /opt/templates/AGENTS_EXTRA.md
COPY entrypoint.d/01-docker-sock.sh /etc/entrypoint.d/01-docker-sock.sh
RUN chmod +x /etc/entrypoint.d/01-docker-sock.sh

USER sandbox
