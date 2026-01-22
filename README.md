# Pterodactyl Yolks Repository

This repository contains custom yolks (eggs) for Pterodactyl Panel. Currently contains **1 yolk**: Hytale.

## Current Yolks

### Hytale
A version of the Hytale yolk addressing:
- OAuth URL not visible in console (fixed with `stdbuf -oL -eL` for unbuffered output)
- Permission denied on credentials file (fixed permissions in Dockerfile/entrypoint)

**Files**: `games/hytale/{Dockerfile, entrypoint.sh, egg-hytale.json}`

**Image**: `ghcr.io/juniorsaldanha/yolks/hytale:latest`

**Import**: Download `games/hytale/egg-hytale.json` → Admin → Nests → Import Egg → Set image to above.

## Repository Structure
```
games/
└── hytale/
    ├── Dockerfile
    ├── entrypoint.sh
    └── egg-hytale.json
```

## Building & Publishing
GitHub Actions auto-builds/pushes multi-platform (amd64/arm64) images to GHCR on `master` pushes/tags.

**Image tags**:
- `:latest`, `:master`, `:short-sha`
- On tags: `:vX.Y.Z`

**Image format**: `ghcr.io/juniorsaldanha/yolks/{game}:{tag}`

Local build:
```bash
cd games/hytale
docker buildx build --platform linux/amd64,linux/arm64 -t test .
docker run -it --rm -e HYTALE_PATCHLINE=release test:latest
```

## Adding New Yolks
1. Add `games/new-game/` with `Dockerfile` & `egg/egg.json`
2. Commit/push → Workflow builds automatically

## Contributing
Fork → Add yolk → PR.

**License**: MIT
## Current Yolks

### Hytale
A version of the Hytale yolk addressing:
- OAuth URL not visible in console (fixed with `stdbuf -oL -eL` for unbuffered output)
- Permission denied on credentials file (fixed permissions in Dockerfile/entrypoint)

**Files**: `games/hytale/{Dockerfile, entrypoint.sh, egg-hytale.json}`

**Image**: `ghcr.io/juniorsaldanha/yolks/hytale:latest`

**Import**: Download `games/hytale/egg-hytale.json` → Admin → Nests → Import Egg → Set image to above.

## Repository Structure
```
games/
└── hytale/
    ├── Dockerfile
    ├── entrypoint.sh
    └── egg-hytale.json
```

## Building & Publishing
GitHub Actions auto-builds/pushes multi-platform (amd64/arm64) images to GHCR on `master` pushes/tags.

**Image tags**:
- `:latest`, `:master`, `:short-sha`
- On tags: `:vX.Y.Z`

Local build:
```bash
cd games/hytale
docker buildx build --platform linux/amd64,linux/arm64 -t test .
docker run -it --rm -e HYTALE_PATCHLINE=release test:latest
```

## Adding New Yolks
1. Add `games/new-game/` with `Dockerfile` & `egg/egg.json`
2. Commit/push → Workflow builds automatically

## Contributing
Fork → Add yolk → PR.

**License**: MIT

