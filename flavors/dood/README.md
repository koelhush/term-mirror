# 🐳 Docker-outside-of-Docker (DooD) Flavor

A specialized flavor designed for AI coding agents that need to orchestrate Docker containers or build container images.

### Quickstart

```bash
docker run -d --name term_mirror_dood \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd):/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  term-mirror:dood
```
