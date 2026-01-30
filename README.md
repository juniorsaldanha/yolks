# 🥚 Pterodactyl Yolks

A collection of custom, optimized eggs (yolks) for [Pterodactyl Panel](https://pterodactyl.io). These images are built to be secure, lightweight (Alpine-based where possible), and easy to use.

## 🤔 What is a Yolk?

In the Pterodactyl ecosystem:
*   **Egg**: A JSON configuration file that tells the panel how to install, configure, and run a specific game server. It defines startup commands, variables, and the Docker image to use.
*   **Yolk (Docker Image)**: The container environment where the game server actually runs. It contains the necessary system libraries (like Java, libc, etc.).

This repository provides both the optimized **Docker Images** (Yolks) and the configuration **Eggs** needed to run them.

## 🎮 Available Games

| Game | Description | Docker Image | Egg File |
|------|-------------|--------------|----------|
| **Hytale** | Fixed OAuth flow, Source Query support, Debian-based installer. | `ghcr.io/juniorsaldanha/yolks/hytale` | [egg-hytale.json](./games/hytale/egg-hytale.json) |

## 📥 How to Install

To add these games to your Pterodactyl Panel, follow these steps:

### 1. Download the Egg
1.  Locate the game you want in the table above.
2.  Click the link in the **Egg File** column (e.g., `egg-hytale.json`).
3.  Save the file to your computer (Right-click "Raw" -> "Save As..." on GitHub).

### 2. Import into Pterodactyl
1.  Log in to your **Pterodactyl Admin Panel**.
2.  Navigate to **Nests** in the sidebar.
3.  Click on the green **Import Egg** button.
4.  **Select File**: Choose the `.json` file you downloaded.
5.  **Associated Nest**: Select the category for the game (e.g., "Minecraft" or create a custom Nest).
6.  Click **Import**.

### 3. Deploy a Server
1.  Go to **Servers** -> **Create New**.
2.  In "Nest Configuration", select the Nest used above.
3.  Select the **Egg** you just imported (e.g., "Hytale").
4.  Fill in the required variables (like server name, password, etc.).
5.  Click **Create Server**.

The panel will automatically pull the optimized Docker image and install the game!

## 🛠️ Development

We use GitHub Actions to automatically build and push Docker images to GHCR.

### Versioning Strategy
*   **Stable Releases**: Tagging `vX.Y.Z` pushes `X.Y.Z` and `latest`.
*   **Development**: Pushing to `develop` branch pushes the `develop` tag.
*   **Production**: Merging to `main` pushes the `latest` tag.

### Adding a New Game
1.  Create `games/<game-name>/`.
2.  Add `Dockerfile`, `entrypoint.sh`, and `egg-<game>.json`.
3.  Push to git; the CI/CD pipeline handles the build.

## 📄 License
MIT License
