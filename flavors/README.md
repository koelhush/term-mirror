# 🧩 Modular Flavors

TermMirror adopts a **Core Base + Modular Flavors** architectural philosophy:
- **Core Base**: Keeps the foundation minimal, clean, and vendor-neutral, providing only the primary PTY hub, SSH gateway, Web Console, and core agent governance.
- **Flavors**: Custom domain workloads (specialized runtimes, toolchains, databases, or orchestrators) extend cleanly under `flavors/` without polluting the base image.

---

## Flavor Design Specification

Each flavor should serve as an independent build unit with the following recommended directory layout:

```text
flavors/<flavor-name>/
├── Dockerfile          # Extends FROM term-mirror:latest, installs domain dependencies
├── entrypoint.d/       # Lifecycle hook scripts (executed by base entrypoint.sh on boot)
│   └── 10-init.sh
├── templates/          # Flavor-specific rules (e.g., AGENTS_EXTRA.md) or configs
└── README.md           # Usage documentation and one-liner run command
```

---

## Official Reference Flavor

- **`dood` (Docker-outside-of-Docker)**:
  - Purpose-built for agents that need to orchestrate Docker containers or build container images;
  - Bundles the `docker.io` CLI and automatically configures `/var/run/docker.sock` for non-root execution.
