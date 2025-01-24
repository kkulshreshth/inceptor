#!/bin/bash

# Define variables
BIN_NAME="inceptor"
BIN_PATH="/usr/local/bin/$BIN_NAME"
GITHUB_REPO="kkulshreshth/inceptor"
RELEASE_URL="https://api.github.com/repos/kkulshreshth/inceptor/releases/latest"

# Function to fetch the latest release version from GitHub
get_latest_version() {
    curl -s "$RELEASE_URL" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to get the current installed version of the binary
get_current_version() {
    $BIN_PATH --version 2>/dev/null || echo "none"
}

# Function to download and replace the binary
upgrade_binary() {
    LATEST_VERSION=$1
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_VERSION/$BIN_NAME"

    echo "Downloading the latest version: $latest_version"
    curl -L -o /tmp/$BIN_NAME $DOWNLOAD_URL
    
    echo "Replacing the old binary with the new one..."
    sudo mv /tmp/$BIN_NAME $BIN_PATH
    sudo chmod +x $BIN_PATH

    echo "Upgrade complete. You are now running version $LATEST_VERSION."
}

# Get the latest and current versions
latest_version=$(get_latest_version)
current_version_temp=$(get_current_version)
current_version="v$current_version_temp"

echo "Current version: $current_version"
echo "Latest version: $latest_version"

# Compare versions and decide if an upgrade is needed
if [ "$current_version" = "$latest_version" ]; then
    echo "You are already on the latest version."
else
    echo "A new version is available. Upgrading from $current_version to $latest_version..."
    upgrade_binary "$latest_version"
fi