# qBittorrent Classic WebUI

## 中文

### 为什么做这个工作流

一直不喜欢新版 qBittorrent WebUI 的颜色：太亮、太艳，长时间看有点晃眼。

更喜欢以前偏灰度、低饱和、紧凑的界面，所以做了这个工作流：保留新版 qBittorrent 官方 WebUI，只覆盖视觉样式，尽量找回以前的感觉。

- 功能、WebAPI、页面逻辑：来自对应版本的 qBittorrent 官方 WebUI
- Classic：只修改 CSS 视觉样式
- GitHub Actions：自动跟随 qBittorrent 官方稳定版构建 Release

### 安装

1. 在 **Releases** 下载：

```text
classic-webui.zip
```

2. 找到宿主机中**映射到容器 `/config` 的目录**。

NAS 文件管理器通常会按压缩包名创建文件夹。把 `classic-webui.zip` 解压到该目录后，应得到：

```text
classic-webui/
├── public/
├── private/
├── translations/
└── COPYING
```

如果使用命令行，请明确解压到 `classic-webui` 目录：

```bash
unzip classic-webui.zip -d ./classic-webui
```

例如 Docker 已有：

```yaml
volumes:
  - ./config:/config
```

最终宿主机目录应为：

```text
./config/classic-webui
```

**不需要额外增加 WebUI volume 映射。**

3. 打开 qBittorrent：

```text
工具 → 选项 → Web UI
```

启用 **使用备选 WebUI**，文件位置填写：

```text
/config/classic-webui
```

4. 保存并刷新浏览器。

### 更新

下载新 Release，用新的 `classic-webui` 目录替换旧目录即可。qBittorrent 里的路径保持不变：

```text
/config/classic-webui
```

---

## English

### Why this workflow

I never liked the newer qBittorrent WebUI colors — they are brighter and more saturated than the older interface.

This project keeps the official qBittorrent WebUI and only applies a Classic CSS layer to bring back a lower-saturation, gray and compact look.

- Functionality, WebAPI and page logic: official qBittorrent WebUI
- Classic layer: CSS-only visual changes
- GitHub Actions: automatically builds releases from the latest stable qBittorrent release

### Installation

1. Download from **Releases**:

```text
classic-webui.zip
```

2. Locate the host directory already mounted to `/config` in the qBittorrent container.

Most NAS file managers create a directory from the archive name automatically. After extraction, the result should be:

```text
classic-webui/
├── public/
├── private/
├── translations/
└── COPYING
```

For command-line extraction, explicitly extract into the `classic-webui` directory:

```bash
unzip classic-webui.zip -d ./classic-webui
```

Example Docker mapping:

```yaml
volumes:
  - ./config:/config
```

Final host path:

```text
./config/classic-webui
```

No additional WebUI volume mount is required.

3. In qBittorrent open:

```text
Tools → Options → Web UI
```

Enable **Use alternative WebUI** and set the files location to:

```text
/config/classic-webui
```

4. Save and refresh the browser.

### Updating

Replace the existing `classic-webui` directory with the one from the newest Release. Keep the qBittorrent path unchanged:

```text
/config/classic-webui
```
