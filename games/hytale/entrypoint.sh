#!/bin/bash

cd /home/container

# Ensure HOME is properly set and writable
export HOME=/home/container

# The hytale-downloader writes credentials to $HOME/.hytale-downloader-credentials.json
CREDENTIALS_FILE="$HOME/.hytale-downloader-credentials.json"

# System files location
HYTALE_BIN="/opt/hytale/bin"
HYTALE_ASSETS="/opt/hytale/assets"

# Remove empty or corrupted credentials file (causes "unexpected end of JSON input" error)
if [[ -f "$CREDENTIALS_FILE" ]]; then
    # Check if file is empty or not valid JSON
    if [[ ! -s "$CREDENTIALS_FILE" ]] || ! jq empty "$CREDENTIALS_FILE" 2>/dev/null; then
        echo "Removing invalid/empty credentials file..."
        rm -f "$CREDENTIALS_FILE"
    fi
fi

# If HYTALE_SERVER_SESSION_TOKEN isn't set, assume the user will log in themselves
if [[ -z "$HYTALE_SERVER_SESSION_TOKEN" ]]; then

    # Determine the correct downloader binary path
    if [[ -x "$HYTALE_BIN/hytale-downloader-linux-amd64" ]]; then
        DOWNLOADER="$HYTALE_BIN/hytale-downloader-linux-amd64"
    elif [[ -x "$HYTALE_BIN/hytale-downloader-linux" ]]; then
        DOWNLOADER="$HYTALE_BIN/hytale-downloader-linux"
    else
        echo "ERROR: hytale-downloader not found. Please run the installer first."
        echo "Expected location: $HYTALE_BIN/hytale-downloader-linux-amd64"
        exit 1
    fi

    # Check if we need to download/update
    curversion=$(timeout 10s $DOWNLOADER -print-version 2>&1 || echo "unknown")

    # If version check timed out or failed, check if server files exist
    if [[ "$curversion" == "unknown" ]] && [[ -f "$HYTALE_ASSETS/HytaleServer.jar" ]]; then
        echo "Version check timed out, but server files exist. Skipping download."
        curversion="existing"
        echo "$curversion" > /opt/hytale/version
    fi

    if ! [[ -e /opt/hytale/version ]] || [ "$curversion" != "$(cat /opt/hytale/version)" ]; then
        echo ""
        echo "=========================================="
        echo "  HYTALE SERVER DOWNLOAD/UPDATE"
        echo "=========================================="
        echo ""
        echo "Starting Hytale Downloader..."
        echo "If you need to authenticate, the OAuth URL will appear below."
        echo "Please wait for the authentication prompt..."
        echo ""

        # Download to /opt/hytale (system files)
        cd /opt/hytale
        stdbuf -oL -eL $DOWNLOADER -patchline "$HYTALE_PATCHLINE" -download-path HytaleServer.zip
        DOWNLOAD_EXIT_CODE=$?

        if [ $DOWNLOAD_EXIT_CODE -ne 0 ]; then
            echo ""
            echo "ERROR: Hytale Downloader failed with exit code $DOWNLOAD_EXIT_CODE"
            echo ""
            echo "Common issues:"
            echo "  - OAuth timeout: Make sure to complete authentication within the time limit"
            echo "  - Permission denied: Check if the server has proper file permissions"
            echo "  - Network issues: Check your internet connection"
            echo ""
            exit $DOWNLOAD_EXIT_CODE
        fi

        echo "Download completed. Extracting..."
        unzip -o HytaleServer.zip -d assets
        rm -f HytaleServer.zip
        echo "$curversion" > /opt/hytale/version
        echo "Extraction complete."
        
        cd /home/container
    else
        echo "Hytale server is already up to date (version: $curversion)"
    fi

elif [[ -f "HytaleMount/HytaleServer.zip" ]]; then
    cd /opt/hytale
    unzip -o /home/container/HytaleMount/HytaleServer.zip -d assets
    cd /home/container
fi

# Ensure Server directory exists
mkdir -p Server

# Update config.json with user-defined settings (Pterodactyl handles this, but we keep for manual override)
if [[ -f Server/config.json ]]; then
    echo "Applying server configuration..."

    # MaxViewRadius
    if [[ -n "$HYTALE_MAX_VIEW_RADIUS" ]]; then
        jq ".MaxViewRadius = $HYTALE_MAX_VIEW_RADIUS" Server/config.json > Server/config.tmp.json && mv Server/config.tmp.json Server/config.json
        echo "  - MaxViewRadius: $HYTALE_MAX_VIEW_RADIUS"
    fi

    # MaxPlayers
    if [[ -n "$HYTALE_MAX_PLAYERS" ]]; then
        jq ".MaxPlayers = $HYTALE_MAX_PLAYERS" Server/config.json > Server/config.tmp.json && mv Server/config.tmp.json Server/config.json
        echo "  - MaxPlayers: $HYTALE_MAX_PLAYERS"
    fi

    # GameMode
    if [[ -n "$HYTALE_GAME_MODE" ]]; then
        jq ".Defaults.GameMode = \"$HYTALE_GAME_MODE\"" Server/config.json > Server/config.tmp.json && mv Server/config.tmp.json Server/config.json
        echo "  - GameMode: $HYTALE_GAME_MODE"
    fi

    # Password
    if [[ -n "$HYTALE_PASSWORD" ]]; then
        jq ".Password = \"$HYTALE_PASSWORD\"" Server/config.json > Server/config.tmp.json && mv Server/config.tmp.json Server/config.json
        echo "  - Password: [set]"
    fi
fi

echo ""
echo "Starting Hytale server..."
echo ""

# Set environment variables
TZ=${TZ:-UTC}
export TZ
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Change to Server directory
cd /home/container/Server

# Print Java version
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"
java -version

# Convert startup variables and run
# The STARTUP variable comes from Pterodactyl
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
exec env ${PARSED}

