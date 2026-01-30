# Pterodactyl Yolks AGENTS.md

## Project Overview
Pterodactyl Panel yolks (eggs) repository. Each `games/<game>/` contains:
- `Dockerfile`: Multi-stage Pterodactyl-compatible image (base alpine/java, entrypoint)
- `egg-<game>.json`: Pterodactyl egg config (variables, startup, scripts)
- `entrypoint.sh`: Startup logic (downloaders, config patching, unbuffered output)

Current: 1 yolk - Hytale (OAuth fixes, permissions, Debian-based installer, Source Query support).

## Essential Commands
**Local Build/Test**:
```bash
cd games/hytale
docker buildx build --platform linux/amd64,linux/arm64 -t test:latest .
docker run -it --rm -e HYTALE_PATCHLINE=release test:latest
```

**Deploy**: GitHub Actions auto-builds/pushes:
- **Main Branch**: `ghcr.io/juniorsaldanha/yolks/<game>:latest` (Production)
- **Develop Branch**: `ghcr.io/juniorsaldanha/yolks/<game>:develop` (Development)
- **Tags**: `v*` (Stable -> latest, RC -> exact version only)
- Platforms: amd64, arm64

**Egg Import**: Admin → Nests → Import `egg-*.json` → Set image.

No local tests/lint observed.

## Code Patterns
- **Dockerfiles**: FROM pterodactyl base (Alpine preferred), COPY entrypoint, USER container, ENTRYPOINT
- **entrypoint.sh**: Bash, handles downloads (stdbuf -oL -eL for console), jq config patching. **System files in `/home/container/.hytale`**.
- **egg.json**: PTDL_v2, startup with env vars, installation script installs deps/downloader. **Config management via egg**.
- Naming: kebab-case dirs (`hytale`), descriptive vars (HYTALE_*)

## Gotchas
- Workflow matrix needs clean JSON `[\"hytale\"]`
- Egg `docker_images` must match GHCR format
- Hytale: OAuth needs unbuffered output (`stdbuf`), credentials perms (`chmod/chown`)
- **File Structure**: System files hidden in `/home/container/.hytale`. `config.json` is managed by Pterodactyl.
- No tests; validate via `docker run`
- GHCR login uses GITHUB_TOKEN

## Conventions
- License: MIT
- Branches: `main` (Stable), `develop` (Bleeding Edge)
- Style: Standard bash/Dockerfile, 2-space YAML indent
- No one-letter vars