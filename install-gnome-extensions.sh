#!/usr/bin/env bash

set -euo pipefail

### Configuration ###
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions"

### Requirements ###
for cmd in jq curl wget unzip gnome-extensions; do
    if ! command -v "$cmd" >/dev/null; then
        echo "❌ Required command '$cmd' is not installed."
        exit 1
    fi
done

### Detect GNOME Version ###
current_shell_version=$(gnome-shell --version | grep -oP '\d+\.\d+')
if [[ -z "$current_shell_version" ]]; then
    echo "❌ Could not detect GNOME Shell version."
    exit 1
fi

echo "🧠 Detected GNOME Shell version: $current_shell_version"
echo

### Check args ###
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <extension-url> [<extension-url> ...]"
    exit 1
fi

### Process URLs ###
for url in "$@"; do
    echo "🔗 Processing: $url"
    id=$(echo "$url" | cut -d/ -f5)
    metadata_url="https://extensions.gnome.org/extension-info/?pk=${id}"
    metadata=$(curl -s "$metadata_url")


    if [[ -z "$metadata" ]]; then
        echo "❌ Failed to fetch metadata for extension ID $id"
        continue
    fi

    uuid=$(echo "$metadata" | jq -r '.uuid')
    supported_versions=$(echo "$metadata" | jq -r '.shell_version_map | keys[]')
    shell_map=$(echo "$metadata" | jq '.shell_version_map')

    version_info=$(echo "$shell_map" | jq -r --arg v "$current_shell_version" '.[$v]')
    use_latest=false

    if [[ "$version_info" == "null" ]]; then
        echo "⚠️  Extension does not officially support GNOME $current_shell_version."
        echo "Skipping..."
        continue
    fi

    extension_version=$(echo "$version_info" | jq -r '.version')
    download_path=$(echo "$metadata" | jq -r '.download_url')
    download_url="https://extensions.gnome.org${download_path}"
    filename=$(basename "$download_url")
    tmp_zip="/tmp/${filename}"


    echo "⬇️  Downloading $filename..."
    wget -q -O "$tmp_zip" "$download_url"

    if [[ ! -f "$tmp_zip" ]]; then
        echo "❌ Failed to download extension zip."
        continue
    fi

    echo "📂 Extracting to $EXT_DIR/$uuid..."
    mkdir -p "$EXT_DIR/$uuid"
    unzip -q "$tmp_zip" -d "$EXT_DIR/$uuid"

    echo "✅ Installed to $EXT_DIR/$uuid"

    echo "🔌 Enabling extension..."
    gnome-extensions enable "$uuid" || echo "⚠️  Could not enable $uuid (you may need to restart GNOME Shell)"

    echo "✅ Extension $uuid (version $extension_version) is installed and enabled"
    [[ "$use_latest" == "true" ]] && echo "⚠️  Forced install for unsupported GNOME version"
    echo "--------------------------------------"
done

echo "🎉 Done! Restart GNOME Shell (Alt+F2 > 'r' or logout/login) for changes to take effect. (Only needed if any packages were installed)"
