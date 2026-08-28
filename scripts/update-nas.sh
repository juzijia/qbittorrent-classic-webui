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

TMP="${TMPDIR:-/tmp}/qb-classic-update.$$"
ZIP="$TMP/classic-webui-latest.zip"
SHA="$TMP/classic-webui-latest.zip.sha256"
NEW="$TMP/new"
BACKUP="${TARGET}.backup"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP" "$NEW"

download_public() {
    BASE="https://github.com/${REPO}/releases/latest/download"
    curl -fL --retry 3 "$BASE/classic-webui-latest.zip" -o "$ZIP"
    curl -fL --retry 3 "$BASE/classic-webui-latest.zip.sha256" -o "$SHA"
}

download_private() {
    command -v python3 >/dev/null 2>&1 || {
        echo "ERROR: private GitHub repo update requires python3 for Release asset lookup"
        exit 1
    }

    RELEASE_JSON="$TMP/release.json"
    curl -fsSL --retry 3 \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        -o "$RELEASE_JSON"

    asset_url() {
        python3 - "$RELEASE_JSON" "$1" <<'PY'
import json, sys
path, wanted = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    release = json.load(f)
for asset in release.get("assets", []):
    if asset.get("name") == wanted:
        print(asset["url"])
        raise SystemExit(0)
raise SystemExit(f"ERROR: Release asset not found: {wanted}")
PY
    }

    ZIP_URL="$(asset_url classic-webui-latest.zip)"
    SHA_URL="$(asset_url classic-webui-latest.zip.sha256)"

    curl -fL --retry 3 \
        -H "Accept: application/octet-stream" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$ZIP_URL" -o "$ZIP"

    curl -fL --retry 3 \
        -H "Accept: application/octet-stream" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$SHA_URL" -o "$SHA"
}

echo "==> Download latest Classic WebUI"
if [ -n "${GH_TOKEN:-}" ]; then
    echo "    Repository mode: authenticated/private"
    download_private
else
    echo "    Repository mode: public/unauthenticated"
    download_public
fi

echo "==> Verify SHA256"
(
    cd "$TMP"
    sha256sum -c "$(basename "$SHA")"
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
echo "Target: $TARGET"
echo "WebUI root in qBittorrent should remain: /webui"
