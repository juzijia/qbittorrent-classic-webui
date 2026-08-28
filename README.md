# qBittorrent Classic WebUI

## 中文

### 为什么做这个工作流

一直不喜欢新版 qBittorrent WebUI 的颜色：太亮、太艳，长时间看有点晃眼。

更喜欢以前偏灰度、低饱和、紧凑的界面，所以做了这个工作流，把新版 qBittorrent 的官方 WebUI 保留下来，只覆盖视觉样式，尽量找回以前的感觉。

- 功能、WebAPI、页面逻辑：来自对应版本的 qBittorrent 官方 WebUI
- Classic：只修改 CSS 视觉样式
- GitHub Actions：自动跟随 qBittorrent 官方稳定版构建 Release

### 安装

1. 在 **Releases** 下载：

```text
classic-webui-qbX.Y.Z.zip
```

2. 找到宿主机中**映射到容器 `/config` 的目录**，直接把 ZIP 解压到这个目录。

解压后应为：

```text
classic-webui/
├── public/
├── private/
├── translations/
└── COPYING
```

如果你的 Docker 配置类似：

```yaml
volumes:
  - ./config:/config
```

那么最终目录就是：

```text
./config/classic-webui
```

**不需要额外增加 WebUI volume 映射。**

3. 打开 qBittorrent：

```text
工具 → 选项 → Web UI
```

启用：

```text
使用备选 WebUI
```

文件位置填写：

```text
/config/classic-webui
```

4. 保存设置，刷新浏览器即可。

### 更新

以后下载新的 Release，直接用新的 `classic-webui` 文件夹替换旧目录即可。qBittorrent 里的路径保持：

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
classic-webui-qbX.Y.Z.zip
```

2. Extract it inside the host directory that is already mounted to `/config` in the qBittorrent container.

The result should be:

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

Result:

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
