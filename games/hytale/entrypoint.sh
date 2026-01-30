#!/bin/bash

cd /home/container

# Ensure HOME is properly set and writable
export HOME=/home/container

# The hytale-downloader writes credentials to $HOME/.hytale-downloader-credentials.json
CREDENTIALS_FILE="$HOME/.hytale-downloader-credentials.json"

# Check permissions
if ! touch "$HOME/.test_write" 2>/dev/null; then
    echo "ERROR: The container user cannot write to $HOME"
    echo "This is likely a permission issue from a failed install."
    echo "SOLUTION: Go to Settings -> Reinstall Server to fix permissions."
    exit 1
fi
rm -f "$HOME/.test_write"

# System files location (Hidden in .hytale directory)
HYTALE_SYS_DIR="/home/container/.hytale"
HYTALE_BIN="$HYTALE_SYS_DIR/bin"
HYTALE_ASSETS="$HYTALE_SYS_DIR/assets"

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
        echo "hytale-downloader not found. Attempting to auto-install..."
        
        DOWNLOAD_URL="https://downloader.hytale.com/hytale-downloader.zip"
        DOWNLOAD_FILE="/tmp/hytale-downloader.zip"
        
        # Create bin directory if it doesn't exist
        mkdir -p "$HYTALE_BIN"
        
        if curl -L -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"; then
            echo "Download successful. Extracting..."
            
            # Unzip to temporary directory
            unzip -o "$DOWNLOAD_FILE" -d /tmp/hytale-temp
            
            # Move binary
            mv /tmp/hytale-temp/hytale-downloader-linux-amd64 "$HYTALE_BIN/"
            chmod +x "$HYTALE_BIN/hytale-downloader-linux-amd64"
            
            # Clean up
            rm -rf "$DOWNLOAD_FILE" /tmp/hytale-temp
            
            DOWNLOADER="$HYTALE_BIN/hytale-downloader-linux-amd64"
            echo "Successfully installed hytale-downloader to $DOWNLOADER"
        else
            echo "ERROR: Failed to download hytale-downloader. Please run the installer or check internet connection."
            exit 1
        fi
    fi

    # Check if we need to download/update
    AUTO_UPDATE=${AUTO_UPDATE:-1}

    # Helper function to normalize version strings (trim whitespace/newlines)
    normalize_version() {
        echo "$1" | tr -d '[:space:]'
    }

    if [[ -f "$HYTALE_ASSETS/Server/HytaleServer.jar" ]] && [[ "$AUTO_UPDATE" == "0" ]]; then
        echo "Auto-update is disabled (AUTO_UPDATE=0). Skipping version check."
    else
        echo "Checking for Hytale server updates..."
        
        # Capture version from downloader (stderr redirected to /dev/null to avoid noise)
        # We process the output to detect if it's actually an Auth prompt
        RAW_VERSION_OUTPUT=$(timeout 10s $DOWNLOADER -print-version 2>&1 || echo "unknown")
        
        # Check if output contains auth URL or interaction prompts
        if [[ "$RAW_VERSION_OUTPUT" == *"oauth"* ]] || [[ "$RAW_VERSION_OUTPUT" == *"authenticate"* ]]; then
            CUR_VERSION_NORMALIZED="auth_required"
        else
            CUR_VERSION_NORMALIZED=$(normalize_version "$RAW_VERSION_OUTPUT")
        fi

        # Read stored version safely
        if [[ -f "$HYTALE_SYS_DIR/version" ]]; then
            STORED_VERSION=$(cat "$HYTALE_SYS_DIR/version")
            STORED_VERSION_NORMALIZED=$(normalize_version "$STORED_VERSION")
        else
            STORED_VERSION="none"
            STORED_VERSION_NORMALIZED="none"
        fi

        echo "Current remote version: [$CUR_VERSION_NORMALIZED]"
        echo "Local stored version:   [$STORED_VERSION_NORMALIZED]"

        # LOGIC MATRIX:
        # 1. Auth Required + Jar Exists -> SKIP (Warn user)
        # 2. Auth Required + Jar Missing -> DOWNLOAD (Interactive login needed)
        # 3. Version Mismatch -> DOWNLOAD
        # 4. Unknown/Failed + Jar Exists -> SKIP

        if [[ "$CUR_VERSION_NORMALIZED" == "auth_required" ]] && [[ -f "$HYTALE_ASSETS/Server/HytaleServer.jar" ]]; then
            echo "WARNING: Cannot check for updates because the downloader requires authentication."
            echo "Skipping update check since server files successfully exist."
            echo "To force an update, delete the HytaleServer.jar file."
            
        elif [[ "$CUR_VERSION_NORMALIZED" == "unknown" ]] && [[ -f "$HYTALE_ASSETS/Server/HytaleServer.jar" ]]; then
            echo "Version check timed out/failed, but server files exist. Skipping download."
            
        elif [[ "$CUR_VERSION_NORMALIZED" != "$STORED_VERSION_NORMALIZED" ]]; then
            echo "New version detected (or local is missing/auth required)! Starting download..."
            
            echo ""
            echo "=========================================="
            echo "  HYTALE SERVER DOWNLOAD/UPDATE"
            echo "=========================================="
            echo ""
            echo "Starting Hytale Downloader..."
            echo "If you need to authenticate, the OAuth URL will appear below."
            echo "Please wait for the authentication prompt..."
            echo ""

            # Download to system directory
            cd "$HYTALE_SYS_DIR"
            
            # Use stdbuf to ensure unbuffered output so OAuth URL is immediately visible
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
            
            # Only update version file if we actually got a clean version
            if [[ "$CUR_VERSION_NORMALIZED" != "auth_required" ]] && [[ "$CUR_VERSION_NORMALIZED" != "unknown" ]]; then
                echo "$RAW_VERSION_OUTPUT" > version
            else
                 # If we downloaded blindly (auth required), effectively we are "latest" but can't store a version string.
                 # We'll store a placeholder so we don't loop if the check starts working later, 
                 # BUT since the check returns "auth_required", we will skip next time anyway via logic rule #1.
                 echo "auth_required_placeholder" > version
            fi
            
            echo "Extraction complete."
            
            cd /home/container
        else
            echo "Hytale server is already up to date ($CUR_VERSION_NORMALIZED)."
        fi
    fi

elif [[ -f "HytaleMount/HytaleServer.zip" ]]; then
    mkdir -p "$HYTALE_SYS_DIR/assets"
    unzip -o /home/container/HytaleMount/HytaleServer.zip -d "$HYTALE_SYS_DIR/assets"
    cd /home/container
fi

# Ensure Server directory exists
mkdir -p Server

# Update config.json with user-defined settings (Pterodactyl handles this, but we keep for manual override)
if [[ -f Server/config.json ]]; then
    # Check if config is valid JSON
    if [[ ! -s "Server/config.json" ]] || ! jq empty "Server/config.json" 2>/dev/null; then
        echo "WARNING: Server/config.json is empty or invalid. Removing it to allow fresh generation."
        rm -f "Server/config.json"
    else
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
fi

echo ""
echo "Starting Hytale server..."
echo ""

# Set environment variables
TZ=${TZ:-UTC}
export TZ
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Define QUERY_PORT if not set
if [[ -z "${QUERY_PORT}" ]]; then
    export QUERY_PORT=$((SERVER_PORT + 1))
else
    export QUERY_PORT
fi

# If using builtin Source Query, ensure the variable is exposed or configured if handled by Java automatically.
# We respect the env var INSTALL_SOURCEQUERY_PLUGIN but we don't do anything specific with it here
# as the user requested "configured automatically", which might imply Hytale server handles it.

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
