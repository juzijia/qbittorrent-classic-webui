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
NAS ./classic-webui:/webui:ro
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

No personal access token is required for GitHub Actions to publish Releases.

## Release assets

Each Release intentionally contains exactly two files:

```text
classic-webui-qb5.2.3-classic-v1.zip
classic-webui-qb5.2.3-classic-v1.zip.sha256
```

The ZIP root is directly mountable and contains:

```text
public/
private/
translations/
BUILD-INFO.txt
LICENSE.qBittorrent
```

There is no duplicated `latest.zip`. The NAS updater reads the latest GitHub Release metadata and automatically discovers the current versioned ZIP and matching SHA256 file.

## Docker Compose

Keep the host-side mapping relative:

```yaml
volumes:
  - ./config:/config
  - ./downloads:/downloads
  - ./classic-webui:/webui:ro
```

qBittorrent WebUI setting:

```text
Use alternative WebUI: enabled
Files location: /webui
```

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

The updater resolves the latest versioned Release asset, verifies SHA256 and required files, rejects symlinks/non-regular filesystem objects, briefly stops qBittorrent, swaps `./classic-webui`, and starts qBittorrent again. If startup fails, it rolls back the previous WebUI directory.

## Classic visual version

Change `classic/VERSION` when the visual layer changes:

```text
v1
v2
...
```

That produces a new Release even if the upstream qBittorrent version did not change.
