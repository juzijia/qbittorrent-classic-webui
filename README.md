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

## GitHub setup

1. Create an empty repository, e.g. `qbittorrent-classic-webui`.
2. Put this repository package into it and push to the default branch.
3. Open **Actions → Build and release Classic WebUI → Run workflow**.
4. Leave `qb_tag` empty to build the latest official stable qBittorrent release.
5. The scheduled workflow checks once per day; an already-published qBittorrent + Classic version is skipped.

The workflow requires only the repository's built-in `GITHUB_TOKEN` and declares:

```yaml
permissions:
  contents: write
```

No personal access token is required for normal Release publishing.

## Release assets

A successful build publishes both a versioned artifact and a stable "latest" asset:

```text
classic-webui-qb5.2.3-classic-v1.zip
classic-webui-qb5.2.3-classic-v1.zip.sha256
classic-webui-latest.zip
classic-webui-latest.zip.sha256
```

The ZIP root is directly mountable and contains:

```text
public/
private/
translations/
BUILD-INFO.txt
LICENSE.qBittorrent
```

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

Run from the qBittorrent Compose directory:

```bash
sh scripts/update-nas.sh OWNER/REPO
```

The updater downloads the latest Release, verifies SHA256 and required files, rejects symlinks/non-regular filesystem objects, briefly stops qBittorrent, swaps `./classic-webui`, and starts qBittorrent again.

## Classic visual version

Change `classic/VERSION` when the visual layer changes:

```text
v1
v2
...
```

That produces a new Release even if the upstream qBittorrent version did not change.
