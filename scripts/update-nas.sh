#!/bin/sh
set -eu

# Usage (run from the qBittorrent Compose directory):
#   Public repo:
#     sh /path/to/update-nas.sh OWNER/REPO
#
#   Private repo:
#     GH_TOKEN='fine-grained-token-with-Contents-read' \
#       sh /path/to/update-nas.sh OWNER/REPO
#
# Default target matches:
#   - ./classic-webui:/webui:ro

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
NEW="$TMP/new"
BACKUP="${TARGET}.backup"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP" "$NEW"

echo "==> Resolve latest Release"
if [ -n "${GH_TOKEN:-}" ]; then
    echo "    Repository mode: authenticated/private"
    curl -fsSL --retry 3 \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        -o "$RELEASE_JSON"
else
    echo "    Repository mode: public/unauthenticated"
    curl -fsSL --retry 3 \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        -o "$RELEASE_JSON"
fi

ASSET_META="$(python3 - "$RELEASE_JSON" <<'PY'
import json, re, sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    release = json.load(f)

assets = release.get("assets", [])
zips = [a for a in assets if re.fullmatch(r"classic-webui-qb.+-classic-.+\.zip", a.get("name", ""))]
if len(zips) != 1:
    raise SystemExit(f"ERROR: expected exactly one versioned ZIP asset, found {len(zips)}")

zip_asset = zips[0]
sha_name = zip_asset["name"] + ".sha256"
sha_assets = [a for a in assets if a.get("name") == sha_name]
if len(sha_assets) != 1:
    raise SystemExit(f"ERROR: expected SHA256 asset: {sha_name}")
sha_asset = sha_assets[0]

print(zip_asset["name"])
print(zip_asset["url"])
print(zip_asset["browser_download_url"])
print(sha_asset["name"])
print(sha_asset["url"])
print(sha_asset["browser_download_url"])
PY
)"

ZIP_NAME="$(printf '%s\n' "$ASSET_META" | sed -n '1p')"
ZIP_API_URL="$(printf '%s\n' "$ASSET_META" | sed -n '2p')"
ZIP_BROWSER_URL="$(printf '%s\n' "$ASSET_META" | sed -n '3p')"
SHA_NAME="$(printf '%s\n' "$ASSET_META" | sed -n '4p')"
SHA_API_URL="$(printf '%s\n' "$ASSET_META" | sed -n '5p')"
SHA_BROWSER_URL="$(printf '%s\n' "$ASSET_META" | sed -n '6p')"

ZIP="$TMP/$ZIP_NAME"
SHA="$TMP/$SHA_NAME"

echo "    ZIP: $ZIP_NAME"
echo "    SHA: $SHA_NAME"

echo "==> Download Release assets"
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
    sha256sum -c "$SHA_NAME"
)

echo "==> Extract and validate"
unzip -q "$ZIP" -d "$NEW"

for f in \
    "$NEW/public/index.html" \
    "$NEW/private/index.html" \
    "$NEW/private/css/classic.css" \
    "$NEW/translations/webui_zh_CN.qm"
do
    [ -f "$f" ] || { echo "ERROR: missing regular file: $f"; exit 1; }
done

if find "$NEW" -type l -print -quit | grep -q .; then
    echo "ERROR: release contains symlink(s)"
    exit 1
fi

BAD_TYPE="$(find "$NEW" ! -type f ! -type d -print -quit)"
[ -z "$BAD_TYPE" ] || { echo "ERROR: unacceptable file type: $BAD_TYPE"; exit 1; }

echo "==> Replace $TARGET"

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

mv "$NEW" "$TARGET"

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
echo "Installed: $ZIP_NAME"
echo "Target: $TARGET"
echo "WebUI root in qBittorrent should remain: /webui"
