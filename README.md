# qBittorrent Classic WebUI

Official qBittorrent WebUI functionality with a visual-only Classic layer inspired by the compact qBittorrent 4.4.5 WebUI.

## Architecture

```text
qBittorrent official stable release
        ↓
GitHub Actions
        ↓
copy official public/ + private/
compile official WebUI translations (.ts → .qm)
        ↓
inject classic/classic.css
        ↓
validate regular files / no symlinks
        ↓
GitHub Release
        ↓
extract into ./config/classic-webui
        ↓
qBittorrent RootFolder=/config/classic-webui
```

## Repository files

```text
classic/classic.css
classic/VERSION
scripts/build.sh
scripts/update-nas.sh
.github/workflows/build-release.yml
```

## Build triggers

The Release workflow runs in three cases:

- Pushes that change the Classic visual layer, build script, or workflow.
- Manual **Actions → Build and release Classic WebUI → Run workflow**.
- Daily scheduled check for a new official qBittorrent stable release.

If a matching `qBittorrent version + Classic version` Release already exists with the expected two assets, scheduled runs skip rebuilding it.

The workflow uses the repository's built-in `GITHUB_TOKEN` and declares:

```yaml
permissions:
  contents: write
```

## Release assets

Each Release intentionally contains exactly two files:

```text
classic-webui-qb5.2.3-classic-v2.zip
classic-webui-qb5.2.3-classic-v2.zip.sha256
```

The ZIP contains one top-level directory so manual extraction does not scatter files into `config/`:

```text
classic-webui/
├── public/
├── private/
├── translations/
├── BUILD-INFO.txt
└── LICENSE.qBittorrent
```

There is no duplicated `latest.zip`. The NAS updater reads the latest GitHub Release metadata and automatically discovers the current versioned ZIP and matching SHA256 file.

## Docker Compose

No extra WebUI bind mount is required. Keep only the normal qBittorrent mounts:

```yaml
volumes:
  - ./config:/config
  - ./downloads:/downloads
```

Place/extract Classic WebUI at:

```text
./config/classic-webui
```

qBittorrent WebUI setting:

```text
Use alternative WebUI: enabled
Files location: /config/classic-webui
```

## Display density

Classic V2 preserves qBittorrent 5.2.x **Display density** behavior.

- `Default`: current Classic spacing.
- `Compact`: tighter body line-height, torrent rows, filters, toolbar and tabs.

The theme no longer hard-codes one density for both settings.

## NAS update

Run from the qBittorrent Compose directory.

For a public GitHub repository:

```bash
sh /path/to/update-nas.sh juzijia/qbittorrent-classic-webui
```

For a private GitHub repository, provide a fine-grained token with **Contents: Read-only** access to this repository:

```bash
GH_TOKEN='YOUR_FINE_GRAINED_TOKEN' \
  sh /path/to/update-nas.sh juzijia/qbittorrent-classic-webui
```

Do not hard-code the token inside the script or Compose file.

The updater resolves the latest versioned Release asset, verifies SHA256 and required files, rejects symlinks/non-regular filesystem objects, briefly stops qBittorrent, replaces `./config/classic-webui`, and starts qBittorrent again. If startup fails, it rolls back the previous WebUI directory.

## Classic visual version

Change `classic/VERSION` when the visual layer or package contract changes:

```text
v1
v2
...
```
