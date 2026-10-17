#!/usr/bin/env bash
# TermMirror - SSH Login Session Sniffer and Auto-Attach Hook

export WORKDIR="${WORKDIR:-/workspace}"
TARGET_GIT_URL="${WORKGITURL:-${workgiturl:-$WORK_GIT_URL}}"
if [ -n "$TARGET_GIT_URL" ]; then
    CLEAN_URL="${TARGET_GIT_URL%/}"
    REPO_NAME=$(basename -s .git "$CLEAN_URL")
    if [ -d "$WORKDIR/$REPO_NAME" ]; then
        cd "$WORKDIR/$REPO_NAME" 2>/dev/null || cd "$WORKDIR" 2>/dev/null || true
    else
        cd "$WORKDIR" 2>/dev/null || true
    fi
else
    cd "$WORKDIR" 2>/dev/null || true
fi

# Trigger only for interactive SSH sessions outside internal container shell
if [ -n "$SSH_TTY" ] && [ -t 0 ] && [ -z "$AGENT_SANDBOX" ] && [ -z "$TERM_MIRROR" ]; then
    # 1. Safely sync repository if WORKGITURL is configured
    if [ -x /usr/local/bin/sync-workgit ]; then
        /usr/local/bin/sync-workgit
    fi

    # 2. Pass through if one-off command (SSH_ORIGINAL_COMMAND) or attach is disabled
    if [ -n "$SSH_ORIGINAL_COMMAND" ] || [ "${NO_ATTACH:-0}" = "1" ] || [ "${NO_PTY:-0}" = "1" ]; then
        return 0 2>/dev/null || exit 0
    fi

    # 3. Attach to shared pty-hub Master PTY gateway
    if [ -f /usr/local/bin/pty_attach.py ]; then
        exec /usr/bin/python3 /usr/local/bin/pty_attach.py
    fi
fi

# 4. Detach SSH connection on exit without killing persistent background session
if [ -n "$AGENT_SANDBOX" ] || [ -n "$TERM_MIRROR" ]; then
    exit() {
        if pgrep -f "pty_attach.py" >/dev/null 2>&1; then
            pkill -TERM -f "pty_attach.py" 2>/dev/null
        else
            return 0 2>/dev/null || true
        fi
    }
    # Prevent accidental Ctrl-D from terminating shared session
    set -o ignoreeof 2>/dev/null || true
fi
