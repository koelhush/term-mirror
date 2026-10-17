# Docker (DooD) Operational Rules

- This TermMirror flavor is configured for Docker-outside-of-Docker (DooD) operation;
- Use the `docker` CLI inside the container to communicate directly with the host Docker daemon;
- Running DinD (Docker-in-Docker) inside the container is prohibited; all container orchestration must be delegated to the host Docker daemon.
