# qBittorrent Classic WebUI

[中文](README.md)

## Why this workflow

I have never liked the newer qBittorrent WebUI colors. They are brighter and more saturated, and can feel harsh during long sessions.

I prefer the older low-saturation gray look and its simple, compact feel, so I created this workflow.

This project **does not rewrite the qBittorrent WebUI**. Functionality, WebAPI and page logic come directly from the matching official qBittorrent WebUI release. Classic only adds a CSS visual layer.

Starting with **qBittorrent 5.2.0**, the official WebUI added an option to increase display density. Classic WebUI preserves that behavior: the default density stays default, while Compact remains an optional denser layout.

GitHub Actions automatically builds Releases from official stable qBittorrent versions.

## Preview

### Default

![Default](docs/screenshots/default.png)

### Compact (qBittorrent 5.2.0+)

![Compact](docs/screenshots/compact.png)

## Installation

### Docker

1. Download from **Releases**:

```text
classic-webui.zip
```

2. Find the host directory that is already mounted to `/config` in the qBittorrent container, and extract the archive as:

```text
classic-webui/
├── public/
├── private/
├── translations/
└── COPYING
```

Example Docker mapping:

```yaml
volumes:
  - ./config:/config
```

The resulting host path should be:

```text
./config/classic-webui
```

No additional WebUI volume mount is required.

Command-line extraction:

```bash
unzip classic-webui.zip -d ./classic-webui
```

3. In qBittorrent open:

```text
Tools → Options → Web UI
```

Enable **Use alternative WebUI** and set the files location to:

```text
/config/classic-webui
```

4. Save the settings and refresh the browser.

### App store / package version (non-Docker)

If qBittorrent is installed from a NAS app store or package center (for example fnOS, Synology DSM, or similar platforms):

1. Extract `classic-webui.zip` to any directory that qBittorrent can read, for example:

```text
<absolute-path>/classic-webui
```

The directory should directly contain `public/`, `private/` and `translations/`.

2. Open **Tools → Options → Web UI**, enable **Use alternative WebUI**, and set the files location to the actual absolute path of that directory.

3. Save the settings and refresh the browser.

> Make sure the qBittorrent service account has read permission for this directory. Point to the `classic-webui` root directory (the parent of `public`), not to `public` itself. The actual path varies between NAS platforms.

## Updating

Download the newest Release and replace the existing `classic-webui` directory.

- Docker: keep `/config/classic-webui` unchanged in qBittorrent.
- App store / package version: keep the absolute path you configured earlier unchanged.

## Notes

- Functionality, WebAPI, HTML and JavaScript come from the matching official qBittorrent release.
- Classic changes visual CSS only.
- qBittorrent 5.2.0+ supports the official display-density setting; both Default and Compact are preserved.
- `COPYING` is included in the Release archive.
