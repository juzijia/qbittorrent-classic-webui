#!/bin/sh
set -eu

# Run from the host directory that is mounted to /config.
# Default install target: ./classic-webui
# qBittorrent Alternate WebUI path: /config/classic-webui
#
# Public repo:
#   sh /path/to/update-nas.sh OWNER/REPO
#
# Private repo:
#   GH_TOKEN='fine-grained-token-with-Contents-read' \
#     sh /path/to/update-nas.sh OWNER/REPO

REPO="${1:-${REPO:-}}"
TARGET="${TARGET:-./classic-webui}"
CONTAINER="${CONTAINER:-qbittorrent}"

if [ -z "$REPO" ]; then
    echo "Usage: sh update-nas.sh OWNER/REPO"
    exit 1
fi

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl required"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip required"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }

TMP="${TMPDIR:-/tmp}/qb-classic-update.$$"
RELEASE_JSON="$TMP/release.json"
PACKAGE_DIR="$TMP/classic-webui"
BACKUP="${TARGET}.backup"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP" "$PACKAGE_DIR"

echo "==> Resolve latest Release"
if [ -n "${GH_TOKEN:-}" ]; then
    curl -fsSL --retry 3 \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        -o "$RELEASE_JSON"
else
    curl -fsSL --retry 3 \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        -o "$RELEASE_JSON"
fi

ASSET_META="$(python3 - "$RELEASE_JSON" <<'PY'
import json, sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    release = json.load(f)

assets = release.get("assets", [])
by_name = {a.get("name"): a for a in assets}
zip_asset = by_name.get("classic-webui.zip")
sha_asset = by_name.get("classic-webui.zip.sha256")

if not zip_asset:
    raise SystemExit("ERROR: classic-webui.zip not found in latest Release")
if not sha_asset:
    raise SystemExit("ERROR: classic-webui.zip.sha256 not found in latest Release")

print(zip_asset["url"])
print(zip_asset["browser_download_url"])
print(sha_asset["url"])
print(sha_asset["browser_download_url"])
PY
)"

ZIP_API_URL="$(printf '%s\n' "$ASSET_META" | sed -n '1p')"
ZIP_BROWSER_URL="$(printf '%s\n' "$ASSET_META" | sed -n '2p')"
SHA_API_URL="$(printf '%s\n' "$ASSET_META" | sed -n '3p')"
SHA_BROWSER_URL="$(printf '%s\n' "$ASSET_META" | sed -n '4p')"

ZIP="$TMP/classic-webui.zip"
SHA="$TMP/classic-webui.zip.sha256"

echo "==> Download classic-webui.zip"
if [ -n "${GH_TOKEN:-}" ]; then
    curl -fL --retry 3 \
        -H "Accept: application/octet-stream" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$ZIP_API_URL" -o "$ZIP"

    curl -fL --retry 3 \
        -H "Accept: application/octet-stream" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$SHA_API_URL" -o "$SHA"
else
    curl -fL --retry 3 "$ZIP_BROWSER_URL" -o "$ZIP"
    curl -fL --retry 3 "$SHA_BROWSER_URL" -o "$SHA"
fi

echo "==> Verify SHA256"
(
    cd "$TMP"
    sha256sum -c "classic-webui.zip.sha256"
)

echo "==> Extract and validate"
unzip -q "$ZIP" -d "$PACKAGE_DIR"

for f in \
    "$PACKAGE_DIR/public/index.html" \
    "$PACKAGE_DIR/private/index.html" \
    "$PACKAGE_DIR/private/css/classic.css" \
    "$PACKAGE_DIR/translations/webui_zh_CN.qm" \
    "$PACKAGE_DIR/COPYING"
do
    [ -f "$f" ] || { echo "ERROR: missing regular file: $f"; exit 1; }
done

if find "$PACKAGE_DIR" -type l -print -quit | grep -q .; then
    echo "ERROR: release contains symlink(s)"
    exit 1
fi

BAD_TYPE="$(find "$PACKAGE_DIR" ! -type f ! -type d -print -quit)"
[ -z "$BAD_TYPE" ] || { echo "ERROR: unacceptable file type: $BAD_TYPE"; exit 1; }

echo "==> Replace $TARGET"
mkdir -p "$(dirname "$TARGET")"

WAS_RUNNING=false
if docker inspect "$CONTAINER" >/dev/null 2>&1; then
    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = "true" ]; then
        WAS_RUNNING=true
        docker stop "$CONTAINER" >/dev/null
    fi
fi

rm -rf "$BACKUP"
if [ -e "$TARGET" ]; then
    mv "$TARGET" "$BACKUP"
fi

mv "$PACKAGE_DIR" "$TARGET"

if [ "$WAS_RUNNING" = "true" ]; then
    if ! docker start "$CONTAINER" >/dev/null; then
        echo "ERROR: qBittorrent failed to start; rolling back"
        rm -rf "$TARGET"
        if [ -e "$BACKUP" ]; then
            mv "$BACKUP" "$TARGET"
        fi
        docker start "$CONTAINER" >/dev/null || true
        exit 1
    fi
fi

rm -rf "$BACKUP"

echo
echo "UPDATE_OK"
echo "Target: $TARGET"
echo "qBittorrent Alternate WebUI path: /config/classic-webui"
