# PhotoView - 高性能 macOS 相册应用

[English](#english) | [中文](#中文)

---

## English

# PhotoView - High Performance macOS Photo Gallery

PhotoView is a lightweight, high-performance photo gallery application designed exclusively for macOS. Inspired by Pixea and AmazePhoto, it aims to provide an ultimate browsing experience while maintaining system smoothness and stability.

## Features

- **Blazing Fast Loading**
  - SQLite-based metadata caching for millisecond-level response.
  - Lazy loading strategy: load thumbnails only when needed in current view.
  - On-demand scanning: folder tree management, scan subdirectories only when expanded or selected.

- **Full Format Video Support**
  - Native support for MP4, MOV, MKV and more.
  - Smart fallback: automatically switch to WKWebView for unsupported WebM format.

- **Smart Folder Management**
  - Add/remove multiple root folders.
  - Sidebar tree view with clear hierarchy.
  - Right-click menu to locate files in Finder.

- **Immersive Fullscreen Browsing**
  - Double-click to enter independent fullscreen window.
  - AVPlayer and WKWebView hybrid rendering engine.
  - Audio cleanup on window close - no "ghost playback".
  - Keyboard shortcuts: left/right to navigate, up/down for seek, space to pause, ESC to exit.

- **Clean Modern UI**
  - Built with SwiftUI, supports dark mode.
  - Adjustable thumbnail size.
  - Bottom toolbar shows progress and volume.

## Technical Stack

- **Language**: Swift 6.0
- **UI Framework**: SwiftUI + AppKit (hybrid architecture)
- **Core Components**:
  - `SQLite3`: Efficient metadata storage
  - `AVFoundation`: High-performance video/audio decoding
  - `WebKit`: WebM format compatibility
  - `ImageIO`: Hardware-accelerated thumbnail generation

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ or Swift 5.9+ command line tools

### Build & Run
```bash
# Build project
swift build -c release

# Run application
swift run PhotoView
```

Or open `Package.swift` in Xcode, select PhotoView target and press Cmd+R.

## Development Roadmap

- [ ] Video subtitle support
- [ ] Batch export/rename functionality
- [ ] CoreML-based intelligent image classification
- [ ] iCloud sync support

## License

For learning and personal use only.

---

## 中文

# PhotoView - 高性能 macOS 相册应用

PhotoView 是一款专为 macOS 打造的轻量级、高性能相册浏览工具。灵感来源于 Pixea 和 AmazePhoto，旨在提供极致的浏览体验，同时保持系统的流畅与稳定。

## 核心特性

- **极速加载体验**
  - 基于 SQLite 的元数据缓存，实现毫秒级响应。
  - 懒加载策略：仅在当前视图需要时加载缩略图，避免内存溢出。
  - 按需扫描：文件夹树状管理，仅在展开或选中时扫描子目录，启动速度极快。

- **全格式视频支持**
  - 原生支持 MP4, MOV, MKV 等常见格式。
  - 智能降级方案：针对 macOS 原生不支持的 WebM 格式，自动切换至 WKWebView 渲染，确保无缝播放。

- **智能文件夹管理**
  - 支持添加/移除多个根文件夹。
  - 侧边栏树状显示子文件夹，层级清晰。
  - 右键菜单快速在 Finder 中定位文件。

- **沉浸式全屏浏览**
  - 双击图片/视频进入独立全屏窗口。
  - 支持 AVPlayer 与 WKWebView 混合渲染引擎。
  - 防声音残留设计：关闭窗口时彻底清理音频资源，拒绝后台"幽灵播放"。
  - 键盘快捷键：左右键切换，上下键快进/退，空格暂停，ESC 退出。

- **简洁现代的 UI**
  - 基于 SwiftUI 构建，支持深色模式。
  - 可调节缩略图大小，适应不同屏幕尺寸。
  - 底部工具栏显示进度与音量，支持拖拽移动。

## 技术栈

- **语言**: Swift 6.0
- **UI 框架**: SwiftUI + AppKit (混合架构)
- **核心组件**:
  - `SQLite3`: 高效元数据存储与索引
  - `AVFoundation`: 高性能视频/音频解码
  - `WebKit`: WebM 格式兼容方案
  - `ImageIO`: 硬件加速缩略图生成

## 安装与运行

### 环境要求
- macOS 14.0 (Sonoma) 及以上
- Xcode 15.0+ 或 Swift 5.9+ 命令行工具

### 构建与运行
```bash
# 编译项目
swift build -c release

# 运行应用
swift run PhotoView
```

或者在 Xcode 中打开 `Package.swift`，选择 `PhotoView` 目标并点击运行 (Cmd + R)。

## 开发计划

- [ ] 支持视频字幕加载
- [ ] 批量导出/重命名功能
- [ ] 基于 CoreML 的图像智能分类
- [ ] iCloud 同步支持

## 许可证

本项目仅供学习与个人使用。
