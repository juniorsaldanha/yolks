#!/bin/bash

cd /home/container

# Ensure HOME is properly set and writable
export HOME=/home/container

# The hytale-downloader writes credentials to $HOME/.hytale-downloader-credentials.json
CREDENTIALS_FILE="$HOME/.hytale-downloader-credentials.json"

# Remove empty or corrupted credentials file (causes "unexpected end of JSON input" error)
if [[ -f "$CREDENTIALS_FILE" ]]; then
    # Check if file is empty or not valid JSON
    if [[ ! -s "$CREDENTIALS_FILE" ]] || ! jq empty "$CREDENTIALS_FILE" 2>/dev/null; then
        echo "Removing invalid/empty credentials file..."
        rm -f "$CREDENTIALS_FILE"
    fi
fi

# If HYTALE_SERVER_SESSION_TOKEN isn't set, assume the user will log in themselves, rather than a host's GSP
if [[ -z "$HYTALE_SERVER_SESSION_TOKEN" ]]; then

    # Determine the correct downloader binary path
    # The binary can be named differently depending on the download/extraction method
    if [[ -x "./hytale-downloader/hytale-downloader-linux-amd64" ]]; then
        DOWNLOADER="./hytale-downloader/hytale-downloader-linux-amd64"
    elif [[ -x "./hytale-downloader/hytale-downloader-linux" ]]; then
        DOWNLOADER="./hytale-downloader/hytale-downloader-linux"
    else
        echo "ERROR: hytale-downloader not found. Please run the installer first."
        echo "Expected location: ./hytale-downloader/hytale-downloader-linux-amd64"
        exit 1
    fi

    # Check if we need to download/update
    # Use timeout to prevent hanging on version check, fallback to "unknown" if it times out
    curversion=$(timeout 10s $DOWNLOADER -print-version 2>&1 || echo "unknown")

    # If version check timed out or failed, check if server files exist
    if [[ "$curversion" == "unknown" ]] && [[ -f "Server/HytaleServer.jar" ]]; then
        echo "Version check timed out, but server files exist. Skipping download."
        curversion="existing"
        echo "$curversion" > version
    fi

    if ! [[ -e version ]] || [ "$curversion" != "$(cat "version")" ]; then
        echo ""
        echo "=========================================="
        echo "  HYTALE SERVER DOWNLOAD/UPDATE"
        echo "=========================================="
        echo ""
        echo "Starting Hytale Downloader..."
        echo "If you need to authenticate, the OAuth URL will appear below."
        echo "Please wait for the authentication prompt..."
        echo ""

        # Use stdbuf to ensure unbuffered output so OAuth URL is immediately visible
        # The -oL flag makes stdout line-buffered, -eL makes stderr line-buffered
        # This ensures the OAuth URL is printed immediately without waiting for buffer to fill
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
        unzip -o HytaleServer.zip -d .
        rm -f HytaleServer.zip
        echo "$curversion" > version
        echo "Extraction complete."
    else
        echo "Hytale server is already up to date (version: $curversion)"
    fi

elif [[ -f "HytaleMount/HytaleServer.zip" ]]; then
    unzip -o HytaleMount/HytaleServer.zip -d .
elif [[ -f "HytaleMount/Assets.zip" ]]; then
    ln -s -f HytaleMount/Assets.zip Assets.zip
elif [[ -f "Server/Assets.zip" ]]; then
    ln -s -f Server/Assets.zip Assets.zip
elif [[ -f "HytaleServer.zip" ]]; then
    unzip -o HytaleServer.zip -d .
fi

# Download the latest hytale-sourcequery plugin if enabled
if [ "${INSTALL_SOURCEQUERY_PLUGIN}" == "1" ]; then
    mkdir -p mods
    echo -e "Downloading latest hytale-sourcequery plugin..."
    LATEST_URL=$(curl -sSL https://api.github.com/repos/physgun-com/hytale-sourcequery/releases/latest \
        | grep -oP '"browser_download_url":\s*"\K[^"]+\.jar' || true)
    if [[ -n "$LATEST_URL" ]]; then
        curl -sSL -o mods/hytale-sourcequery.jar "$LATEST_URL"
        echo -e "Successfully downloaded hytale-sourcequery plugin to mods folder."
    else
        echo -e "Warning: Could not find hytale-sourcequery plugin download URL."
    fi
fi

# Update config.json with user-defined settings
if [[ -f config.json ]]; then
    echo "Applying server configuration..."

    # MaxViewRadius
    if [[ -n "$HYTALE_MAX_VIEW_RADIUS" ]]; then
        jq ".MaxViewRadius = $HYTALE_MAX_VIEW_RADIUS" config.json > config.tmp.json && mv config.tmp.json config.json
        echo "  - MaxViewRadius: $HYTALE_MAX_VIEW_RADIUS"
    fi

    # MaxPlayers
    if [[ -n "$HYTALE_MAX_PLAYERS" ]]; then
        jq ".MaxPlayers = $HYTALE_MAX_PLAYERS" config.json > config.tmp.json && mv config.tmp.json config.json
        echo "  - MaxPlayers: $HYTALE_MAX_PLAYERS"
    fi

    # GameMode
    if [[ -n "$HYTALE_GAME_MODE" ]]; then
        jq ".GameMode = \"$HYTALE_GAME_MODE\"" config.json > config.tmp.json && mv config.tmp.json config.json
        echo "  - GameMode: $HYTALE_GAME_MODE"
    fi

    # Password
    if [[ -n "$HYTALE_PASSWORD" ]]; then
        jq ".Password = \"$HYTALE_PASSWORD\"" config.json > config.tmp.json && mv config.tmp.json config.json
        echo "  - Password: [set]"
    fi
fi

# Ensure Assets.zip is accessible to the server
# The download extracts Assets.zip to root and Server/HytaleServer.jar to Server/
# We need to make sure assets are in the right place
if [[ -f "Assets.zip" ]] && [[ ! -f "Server/Assets.zip" ]]; then
    echo "Linking Assets.zip to Server directory..."
    ln -sf ../Assets.zip Server/Assets.zip
fi

# The server looks for assets in specific locations
# If HytaleAssets directory doesn't exist but Assets.zip does, extract it
if [[ ! -d "HytaleAssets" ]] && [[ -f "Assets.zip" ]]; then
    echo "Extracting Assets.zip to HytaleAssets..."
    mkdir -p HytaleAssets
    unzip -o Assets.zip -d HytaleAssets
    echo "Assets extracted."
fi

# Also check if we need to extract in the Server directory
if [[ ! -d "Server/HytaleAssets" ]] && [[ -f "Server/Assets.zip" ]]; then
    echo "Extracting Assets.zip to Server/HytaleAssets..."
    mkdir -p Server/HytaleAssets
    unzip -o Server/Assets.zip -d Server/HytaleAssets
    echo "Assets extracted."
fi

echo ""
echo "Starting Hytale server..."
echo ""

# Set environment variables
TZ=${TZ:-UTC}
export TZ
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Change to Server directory where HytaleServer.jar and HytaleAssets are
cd /home/container/Server

# Print Java version
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"
java -version

# Convert startup variables and run
# The STARTUP variable comes from Pterodactyl and should be: java -Xms128M -XmxXXXXM -jar HytaleServer.jar
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
exec env ${PARSED}

