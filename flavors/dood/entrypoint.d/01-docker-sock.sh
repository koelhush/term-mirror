#!/usr/bin/env bash
# Auto-detect host Docker socket and grant non-privileged access
if [ -S /var/run/docker.sock ]; then
    chmod 666 /var/run/docker.sock 2>/dev/null || true
fi
