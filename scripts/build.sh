#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QBT_TAG="${1:-}"

if [[ -z "$QBT_TAG" ]]; then
    QBT_TAG="$(curl -fsSL https://api.github.com/repos/qbittorrent/qBittorrent/releases/latest \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
fi

if [[ "$QBT_TAG" != release-* ]]; then
    echo "ERROR: qBittorrent tag must look like release-X.Y.Z (got: $QBT_TAG)" >&2
    exit 1
fi

QBT_VERSION="${QBT_TAG#release-}"
WORK_DIR="$ROOT_DIR/.work"
BUILD_ROOT="$ROOT_DIR/build"
BUILD_DIR="$BUILD_ROOT/classic-webui"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE="$WORK_DIR/qbittorrent-${QBT_TAG}.tar.gz"
SOURCE_DIR="$WORK_DIR/source"

rm -rf "$WORK_DIR" "$BUILD_ROOT" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$SOURCE_DIR" "$BUILD_DIR" "$DIST_DIR"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

URL="https://github.com/qbittorrent/qBittorrent/archive/refs/tags/${QBT_TAG}.tar.gz"

echo "==> qBittorrent: $QBT_TAG"
echo "==> Download:    $URL"

curl -fL --retry 3 --connect-timeout 20 "$URL" -o "$ARCHIVE"
tar -xzf "$ARCHIVE" -C "$SOURCE_DIR"

QBT_ROOT="$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'qBittorrent-*' -print -quit)"
if [[ -z "$QBT_ROOT" ]]; then
    echo "ERROR: extracted qBittorrent source directory not found" >&2
    exit 1
fi

WWW="$QBT_ROOT/src/webui/www"
[[ -d "$WWW/private" ]] || { echo "ERROR: upstream private/ missing" >&2; exit 1; }
[[ -d "$WWW/public" ]] || { echo "ERROR: upstream public/ missing" >&2; exit 1; }
[[ -d "$WWW/translations" ]] || { echo "ERROR: upstream translations/ missing" >&2; exit 1; }
[[ -f "$QBT_ROOT/COPYING" ]] || { echo "ERROR: upstream COPYING missing" >&2; exit 1; }

echo "==> Copy official WebUI"
cp -a "$WWW/private" "$BUILD_DIR/"
cp -a "$WWW/public" "$BUILD_DIR/"

echo "==> Compile official WebUI translations (.ts -> .qm)"
if command -v lrelease >/dev/null 2>&1; then
    LRELEASE="$(command -v lrelease)"
elif [[ -x /usr/lib/qt6/bin/lrelease ]]; then
    LRELEASE="/usr/lib/qt6/bin/lrelease"
elif [[ -x /usr/lib/qt5/bin/lrelease ]]; then
    LRELEASE="/usr/lib/qt5/bin/lrelease"
else
    echo "ERROR: lrelease not found. Install qt6-l10n-tools." >&2
    exit 1
fi

mkdir -p "$BUILD_DIR/translations"
for ts in "$WWW"/translations/webui_*.ts; do
    name="$(basename "${ts%.ts}")"
    "$LRELEASE" "$ts" -qm "$BUILD_DIR/translations/${name}.qm" >/dev/null
done

echo "==> Inject Classic visual layer"
cp "$ROOT_DIR/classic/classic.css" "$BUILD_DIR/private/css/classic.css"
cp "$ROOT_DIR/classic/classic.css" "$BUILD_DIR/public/css/classic.css"

inject_css() {
    local file="$1"
    local anchor="$2"
    local href="$3"

    python3 - "$file" "$anchor" "$href" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
anchor = sys.argv[2]
href = sys.argv[3]
text = path.read_text(encoding="utf-8")

if href in text:
    raise SystemExit(0)

lines = text.splitlines(keepends=True)
for i, line in enumerate(lines):
    if anchor in line:
        indent = line[:len(line) - len(line.lstrip())]
        lines.insert(i + 1, f'{indent}<link rel="stylesheet" type="text/css" href="{href}?v=${{CACHEID}}">\n')
        path.write_text("".join(lines), encoding="utf-8")
        break
else:
    raise SystemExit(f"ERROR: CSS anchor not found in {path}: {anchor}")
PY
}

inject_css "$BUILD_DIR/private/index.html" 'css/Tabs.css' 'css/classic.css'
inject_css "$BUILD_DIR/public/index.html" 'css/login.css' 'css/classic.css'

cp "$QBT_ROOT/COPYING" "$BUILD_DIR/COPYING"

echo "==> Validate package"
required=(
    "$BUILD_DIR/public/index.html"
    "$BUILD_DIR/private/index.html"
    "$BUILD_DIR/public/css/classic.css"
    "$BUILD_DIR/private/css/classic.css"
    "$BUILD_DIR/translations/webui_zh_CN.qm"
    "$BUILD_DIR/COPYING"
)

for f in "${required[@]}"; do
    [[ -f "$f" ]] || { echo "ERROR: missing regular file: $f" >&2; exit 1; }
done

grep -q 'css/classic.css' "$BUILD_DIR/private/index.html"
grep -q 'css/classic.css' "$BUILD_DIR/public/index.html"

if find "$BUILD_DIR" -type l -print -quit | grep -q .; then
    echo "ERROR: symlinks are forbidden in qBittorrent Alternate WebUI" >&2
    find "$BUILD_DIR" -type l -print
    exit 1
fi

BAD_TYPE="$(find "$BUILD_DIR" ! -type f ! -type d -print -quit)"
if [[ -n "$BAD_TYPE" ]]; then
    echo "ERROR: unacceptable filesystem object: $BAD_TYPE" >&2
    exit 1
fi

ZIP="$DIST_DIR/classic-webui.zip"

echo "==> Package"
(
    cd "$BUILD_DIR"
    zip -qr "$ZIP" .
)

(
    cd "$DIST_DIR"
    sha256sum "$(basename "$ZIP")" > "$(basename "$ZIP").sha256"
)

echo
echo "BUILD_OK"
echo "qBittorrent=$QBT_VERSION"
echo "Artifact=$ZIP"
