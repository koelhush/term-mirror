# Contributing to TermMirror

First off, thank you for considering contributing to TermMirror! 🎉

---

## 🧭 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## 🛠️ Development Setup

1. **Clone the repository**:
   ```bash
   git clone git@github.com:koelhush/term-mirror.git
   cd term-mirror
   ```

2. **Build the container locally**:
   ```bash
   docker build -t term-mirror:local .
   ```

3. **Run local verification container**:
   ```bash
   docker run -d --name test_term_mirror \
     -p 7681:7681 -p 2222:22 \
     -v $(pwd)/workspace:/workspace \
     term-mirror:local
   ```

4. **Verify dual-interface mirroring**:
   - Access Web Console: `http://127.0.0.1:7681`
   - Connect via SSH: `ssh -p 2222 sandbox@127.0.0.1` (Password: `sandbox`)
   - Test trackpad scrolling and multi-line selection on macOS `Terminal.app`.

---

## 🧩 Adding a New Flavor

We welcome community-contributed Flavors! Please adhere to the following conventions:

1. Create a dedicated directory under `flavors/<flavor-name>/`.
2. Provide a clean `Dockerfile` inheriting `FROM term-mirror:latest`.
3. If background initialization or daemon setup is needed, place executable shell scripts in `entrypoint.d/`.
4. Include a comprehensive `README.md` with usage instructions and an official one-liner launch command.

---

## 📝 Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` Introduces a new feature or capability
- `fix:` Fixes a bug or UX flaw
- `docs:` Documentation only changes
- `refactor:` Code change that neither fixes a bug nor adds a feature
- `perf:` Code change that improves performance
- `test:` Adding or updating tests

---

## 🚀 Pull Request Process

1. Fork the repo and create your branch from `main`:
   ```bash
   git checkout -b feat/my-new-feature
   ```
2. Ensure your changes adhere to project standards and do not introduce proprietary dependencies or credentials.
3. Submit a Pull Request with a clear description of the problem and your solution.
