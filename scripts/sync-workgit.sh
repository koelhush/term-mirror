#!/usr/bin/env bash
# ==============================================================================
# TermMirror - SSH Login Repository Auto-Sync Hook (WORKGITURL)
#
# Rules:
# 1. Default WORKGITURL points to this project repo for out-of-the-box dogfooding.
# 2. If WORKGITURL="", auto-sync is completely disabled for a pure clean workspace.
# 3. If an AI coding agent is currently running, skip sync to avoid write conflicts.
# 4. If target directory is not cloned, execute git clone.
# 5. If target directory is already cloned, execute git pull.
# ==============================================================================

export WORKDIR="${WORKDIR:-/workspace}"
DEFAULT_REPO_URL="git@github.com:koelhush/term-mirror.git"

if [ -n "${WORKGITURL+x}" ]; then
    # User explicitly defined WORKGITURL (including empty string "")
    TARGET_GIT_URL="$WORKGITURL"
else
    # User did not set variable; use default repository
    TARGET_GIT_URL="$DEFAULT_REPO_URL"
fi

# 1. Check environment variable: exit silently if empty
if [ -z "$TARGET_GIT_URL" ]; then
    return 0 2>/dev/null || exit 0
fi

# 2. Check if an interactive AI coding agent is actively running to prevent conflicts
is_agent_running() {
    local running=0
    # Check common coding agent processes
    if pgrep -f "claude" >/dev/null 2>&1 || \
       pgrep -f "aider" >/dev/null 2>&1 || \
       pgrep -f "open-code-interpreter" >/dev/null 2>&1 || \
       pgrep -f "gemini" >/dev/null 2>&1; then
        running=1
    fi
    return $running
}

if is_agent_running; then
    echo "⚡ [workgit] Coding agent is currently active; skipping git sync to avoid write conflicts."
    return 0 2>/dev/null || exit 0
fi

# 3. Ensure storage directory exists
mkdir -p "$WORKDIR"

# 4. Execute git commands under appropriate user context
run_git() {
    if [ "$(id -u)" -eq 0 ]; then
        su - sandbox -c "git $*"
    else
        git "$@"
    fi
}

# 5. Parse repo name and determine target directory ($WORKDIR/<repo_name>)
CLEAN_URL="${TARGET_GIT_URL%/}"
REPO_NAME=$(basename -s .git "$CLEAN_URL")
TARGET_DIR="$WORKDIR/$REPO_NAME"

# 6. Clone or pull repository
if [ -d "$TARGET_DIR/.git" ]; then
    echo "📦 [workgit] Existing git repository detected in $TARGET_DIR, running git pull..."
    if (cd "$TARGET_DIR" && run_git pull --rebase 2>/dev/null || run_git pull); then
        echo "✅ [workgit] Repository successfully updated to latest version."
    else
        echo "⚠️ [workgit] git pull encountered warnings; preserving workspace."
    fi
elif [ -d "$WORKDIR/.git" ]; then
    # Backward compatibility: repo cloned directly into /workspace root
    echo "📦 [workgit] Git repository detected in $WORKDIR root, running git pull..."
    if (cd "$WORKDIR" && run_git pull --rebase 2>/dev/null || run_git pull); then
        echo "✅ [workgit] Repository successfully updated to latest version."
    else
        echo "⚠️ [workgit] git pull encountered warnings; preserving workspace."
    fi
else
    echo "🚀 [workgit] Cloning repository to $TARGET_DIR ..."
    if run_git clone "$TARGET_GIT_URL" "$TARGET_DIR"; then
        echo "✅ [workgit] Repository successfully cloned to $TARGET_DIR."
    else
        echo "⚠️ [workgit] git clone returned non-zero exit code, continuing login."
    fi
fi

# 7. Ensure correct file ownership (sandbox:sandbox 1000:1000)
chown -R sandbox:sandbox "$WORKDIR" 2>/dev/null || true
