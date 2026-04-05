# PhotoView - macOS 相册应用

[English](#english) | [中文](#中文)

---

## English

# PhotoView

PhotoView is a lightweight photo gallery application for macOS.

### Supported Formats

**Images**: JPEG, PNG, GIF, HEIC, TIFF, BMP, WebP
**Videos**: MP4, MOV, MKV, M4V, AVI, WebM

### Technical Stack

- **Language**: Swift 6.0
- **UI Framework**: SwiftUI + AppKit
- **Core Components**:
  - `SQLite3`: Metadata caching
  - `AVFoundation`: Video/audio playback
  - `WebKit`: WebM format support
  - `ImageIO`: Thumbnail generation

### Installation

**Requirements**: macOS 14.0+

**Build & Run**:
```bash
swift build -c release
swift run PhotoView
```

Or open `Package.swift` in Xcode and press Cmd+R.

---

## 中文

# PhotoView

PhotoView 是一款适用于 macOS 的轻量级相册浏览应用。

### 支持格式

**图片**: JPEG, PNG, GIF, HEIC, TIFF, BMP, WebP
**视频**: MP4, MOV, MKV, M4V, AVI, WebM

### 技术栈

- **语言**: Swift 6.0
- **UI 框架**: SwiftUI + AppKit
- **核心组件**:
  - `SQLite3`: 元数据缓存
  - `AVFoundation`: 视频/音频播放
  - `WebKit`: WebM 格式支持
  - `ImageIO`: 缩略图生成

### 安装与运行

**环境要求**: macOS 14.0+

**编译运行**:
```bash
swift build -c release
swift run PhotoView
```

或在 Xcode 中打开 `Package.swift`，按 Cmd+R 运行。

### 许可证

本项目仅供学习与个人使用。
