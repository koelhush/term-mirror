#!/usr/bin/env bash
set -e

# 1. Ensure workspace directory is ready with aligned permissions (1000:1000)
export WORKDIR="${WORKDIR:-/workspace}"
mkdir -p "$WORKDIR"
chown sandbox:sandbox "$WORKDIR" 2>/dev/null || true

# 1.1 If host Docker socket is mounted (DooD mode), grant non-privileged access
if [ -S /var/run/docker.sock ]; then
    chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# Preserve key container environment variables for SSH sessions and WebUI console
TARGET_GIT_URL="${WORKGITURL:-${workgiturl:-$WORK_GIT_URL}}"

{
    echo "# Container environment preservation"
    echo "export WORKDIR=\"$WORKDIR\""
    [ -n "$TARGET_GIT_URL" ] && echo "export WORKGITURL=\"$TARGET_GIT_URL\""
} > /etc/profile.d/00-container-env.sh
chmod 644 /etc/profile.d/00-container-env.sh

if [ -n "$TARGET_GIT_URL" ]; then
    echo "WORKGITURL=\"$TARGET_GIT_URL\"" >> /etc/environment
fi

# 2. If WORKGITURL is configured, perform initial repository checkout and sync
if [ -n "$TARGET_GIT_URL" ] && [ -x /usr/local/bin/sync-workgit ]; then
    echo "[entrypoint] WORKGITURL detected, performing boot-time git sync..."
    /usr/local/bin/sync-workgit || echo "[entrypoint] Warning: Boot-time git sync returned non-zero, continuing boot sequence"
fi

# 3. Standardize legacy agent doc filenames (lowercase agent.md to AGENTS.md)
if [ -f "$WORKDIR/agent.md" ] && [ ! -f "$WORKDIR/AGENTS.md" ]; then
    echo "[entrypoint] Standardizing agent.md to AGENTS.md..."
    mv "$WORKDIR/agent.md" "$WORKDIR/AGENTS.md"
fi

# 4. Inject operational rules into system prompts and config paths (supports sandbox & root, plus flavor extensions)
cat /opt/templates/AGENTS.md > /tmp/merged_agents.md
if [ -f /opt/templates/AGENTS_EXTRA.md ]; then
    echo -e "\n\n# --- 🌟 Active Flavor Domain Rules ---\n" >> /tmp/merged_agents.md
    cat /opt/templates/AGENTS_EXTRA.md >> /tmp/merged_agents.md
fi

for u in sandbox root; do
    h=$(eval echo ~$u)
    mkdir -p "$h/.gemini/config/rules" "$h/.gemini/antigravity-cli"
    cp /tmp/merged_agents.md "$h/.gemini/AGENT.md"
    cp /tmp/merged_agents.md "$h/.gemini/AGENTS.md"
    cp /tmp/merged_agents.md "$h/.gemini/config/rules/AGENTS.md"
    cp /tmp/merged_agents.md "$h/.gemini/config/AGENTS.md"

    if [ ! -s "$h/.gemini/config/mcp_config.json" ]; then
        cp /opt/templates/mcp_config.json "$h/.gemini/config/mcp_config.json"
    fi

    if [ ! -s "$h/.gemini/antigravity-cli/settings.json" ]; then
        cp /opt/templates/settings.json "$h/.gemini/antigravity-cli/settings.json"
    fi
    chown -R "$u:$u" "$h/.gemini" 2>/dev/null || true
done

# 5. Ensure SSH client/server keys (auto-generate isolated keys, support host key mount)
mkdir -p /root/.ssh /home/sandbox/.ssh
chmod 700 /root/.ssh /home/sandbox/.ssh

# If host keys are mounted to /root/.ssh, sync them to the sandbox user
shopt -s nullglob
for keyfile in /root/.ssh/*; do
    if [ -f "$keyfile" ]; then
        fname=$(basename "$keyfile")
        cp "$keyfile" "/home/sandbox/.ssh/$fname" 2>/dev/null || true
    fi
done
shopt -u nullglob

# If no client private key exists, generate a 4096-bit RSA keypair
if [ ! -f /home/sandbox/.ssh/id_rsa ] && [ ! -f /home/sandbox/.ssh/id_ed25519 ]; then
    echo "[entrypoint] Auto-generating default 4096-bit SSH client keypair..."
    ssh-keygen -t rsa -b 4096 -N "" -f /home/sandbox/.ssh/id_rsa -C "sandbox@term-mirror" >/dev/null 2>&1
    cp /home/sandbox/.ssh/id_rsa /root/.ssh/id_rsa 2>/dev/null || true
    cp /home/sandbox/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub 2>/dev/null || true
fi

# Ensure authorized_keys contains local public key with strict permissions
for u in sandbox root; do
    h=$(eval echo ~$u)
    if [ -f "$h/.ssh/id_rsa.pub" ]; then
        cat "$h/.ssh/id_rsa.pub" >> "$h/.ssh/authorized_keys" 2>/dev/null || true
        sort -u "$h/.ssh/authorized_keys" -o "$h/.ssh/authorized_keys" 2>/dev/null || true
    fi
    chown -R "$u:$u" "$h/.ssh" 2>/dev/null || true
    chmod 700 "$h/.ssh" 2>/dev/null || true
    chmod 600 "$h/.ssh"/* 2>/dev/null || true
    [ -f "$h/.ssh/id_rsa.pub" ] && chmod 644 "$h/.ssh/id_rsa.pub" || true
    [ -f "$h/.ssh/id_ed25519.pub" ] && chmod 644 "$h/.ssh/id_ed25519.pub" || true
    [ -f "$h/.ssh/authorized_keys" ] && chmod 600 "$h/.ssh/authorized_keys" || true
done

# Generate missing SSH server host keys (on first boot)
ssh-keygen -A 2>/dev/null || true

# 6. Global Git safe directory and fallback identity
git config --system --add safe.directory "*"
git config --system --get user.name >/dev/null 2>&1 || git config --system user.name "TermMirror Agent"
git config --system --get user.email >/dev/null 2>&1 || git config --system user.email "agent@term-mirror.local"

# 7. Execute flavor lifecycle extension hooks (/etc/entrypoint.d/*.sh)
if [ -d /etc/entrypoint.d ]; then
    shopt -s nullglob
    hooks=(/etc/entrypoint.d/*.sh)
    if [ ${#hooks[@]} -gt 0 ]; then
        echo "[entrypoint] Found ${#hooks[@]} lifecycle hooks, executing..."
        for hook in "${hooks[@]}"; do
            if [ -f "$hook" ]; then
                echo "[entrypoint] ---> Running hook: $(basename "$hook")"
                chmod +x "$hook" 2>/dev/null || true
                "$hook" || echo "[entrypoint] Warning: Hook $hook returned non-zero exit status ($?)"
            fi
        done
        echo "[entrypoint] All lifecycle hooks completed."
    fi
    shopt -u nullglob
fi

# 8. Launch embedded pty-hub in background (manages Master PTY, WebUI on port 7681, Unix Socket)
echo "[entrypoint] Starting embedded pty-hub gateway (Port: 7681, User: sandbox)..."
(while true; do
    python3 -u /usr/local/bin/pty_hub.py
    echo "[entrypoint] Warning: pty-hub exited unexpectedly, restarting in 1s..."
    sleep 1
done) > /var/log/pty-hub.log 2>&1 &

# 9. Print ready status banner
echo "=========================================================="
echo " 🚀 TermMirror v1.0.0 is ready"
echo " 📁 Workspace: $WORKDIR"
[ -n "$TARGET_GIT_URL" ] && echo " 📦 Auto-sync Repo (WORKGITURL): $TARGET_GIT_URL"
echo " 👤 User: sandbox (UID: 1000, GID: 1000, NOPASSWD sudo)"
echo " 🔐 SSH Service: running (port: 22, root / sandbox)"
echo " 🌐 WebUI Console: running (port: 7681, master grid locked)"
echo " ⚡ Single-Master PTY Gateway: pty-hub (native macOS trackpad scrolling)"
echo "=========================================================="

# 10. Start sshd in foreground
exec /usr/sbin/sshd -D -e
