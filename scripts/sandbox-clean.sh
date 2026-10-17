#!/usr/bin/env bash
# ==============================================================================
# TermMirror - Workspace and Session History Cleaner
#
# Cleans bloated conversation histories, temporary logs, and SQLite WAL files
# while preserving auth tokens and primary configurations.
# ==============================================================================

set -e

clean_user_cache() {
    local target_user="$1"
    local target_dir=$(eval echo "~$target_user")

    if [ ! -d "$target_dir" ]; then
        return 0
    fi

    echo "🧹 Cleaning user directory: $target_dir ..."

    # 1. Clean temporary CLI caches and logs
    rm -rf "$target_dir"/.gemini/antigravity-cli/brain/*/scratch/* 2>/dev/null || true
    rm -rf "$target_dir"/.gemini/antigravity-cli/logs/* 2>/dev/null || true
    rm -rf "$target_dir"/.cache/* 2>/dev/null || true
    rm -rf "$target_dir"/.npm/_cacache 2>/dev/null || true

    # 2. Clean temporary build artifacts
    find "$target_dir" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir" -type f -name "*.pyc" -delete 2>/dev/null || true
}

# Clean for sandbox and root
clean_user_cache "sandbox"
clean_user_cache "root"

# Clean system temporary files
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
rm -rf /var/log/pty-hub.log* 2>/dev/null || true

echo "✨ Session history and temporary caches cleaned successfully!"
