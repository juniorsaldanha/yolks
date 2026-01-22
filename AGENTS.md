# Pterodactyl Yolks AGENTS.md

## Project Overview
Pterodactyl Panel yolks (eggs) repository. Each `games/&lt;game&gt;/` contains:
- `Dockerfile`: Multi-stage Pterodactyl-compatible image (base debian/java, entrypoint)
- `egg-&lt;game&gt;.json`: Pterodactyl egg config (variables, startup, scripts)
- `entrypoint.sh`: Startup logic (downloaders, config patching, unbuffered output)

Current: 1 yolk - Hytale (OAuth fixes, permissions).

## Essential Commands
**Local Build/Test**:
```bash
cd games/hytale
docker buildx build --platform linux/amd64,linux/arm64 -t test:latest .
docker run -it --rm -e HYTALE_PATCHLINE=release test:latest
```

**Deploy**: GitHub Actions auto-builds/pushes on `main`/tags:
- Triggers: push `main`, tags `v*`
- Images: `ghcr.io/juniorsaldanha/yolks/&lt;game&gt;:{latest,main,sha,tag}`
- Platforms: amd64, arm64

**Egg Import**: Admin → Nests → Import `egg-*.json` → Set image.

No local tests/lint observed.

## Code Patterns
- **Dockerfiles**: FROM pterodactyl base, COPY entrypoint, USER container, ENTRYPOINT
- **entrypoint.sh**: Bash, handles downloads (stdbuf -oL -eL for console), jq config patching
- **egg.json**: PTDL_v2, startup with env vars, installation script installs deps/downloader
- Naming: kebab-case dirs (`hytale`), descriptive vars (HYTALE_*)

## Gotchas
- Workflow matrix needs clean JSON `[\"hytale\"]`
- Egg `docker_images` must match GHCR format
- Hytale: OAuth needs unbuffered output (`stdbuf`), credentials perms (`chmod/chown`)
- No tests; validate via `docker run`
- GHCR login uses GITHUB_TOKEN

## Conventions
- License: MIT
- Branch: `main`
- Style: Standard bash/Dockerfile, 2-space YAML indent
- No one-letter vars