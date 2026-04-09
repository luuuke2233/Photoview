## 更新内容

### 新增功能
- 视频现在会在应用内独立窗口播放，不再依赖外部播放器。
- 增加视频进度条拖拽、音量滑块调节和自动播放下一个视频功能。
- 新增正式版 `1.5.6` 安装包与 DMG 发布。

### 问题修复
- 修复 `.avi` 视频无法正常播放的问题，改为通过 FFmpeg 转换后在应用内播放。
- 修复 `webm` 视频缩略图显示为黑色的问题，改为提取视频实际帧生成缩略图。
- 修复 `webm` 视频不显示缩略图的问题。

### 优化改进
- 统一视频播放体验，常规视频、WebM 与 AVI 共享一致的窗口控制逻辑。
- 打包流程现在会自动使用 `icon/icon.png` 生成应用图标。

## Release Notes

### New Features
- Videos now open in a dedicated in-app window instead of relying on an external player.
- Added video timeline seeking, volume slider control, and automatic playback of the next video.
- Added official `1.5.6` app and DMG release packaging.

### Bug Fixes
- Fixed `.avi` playback by converting AVI files through FFmpeg before playing them in-app.
- Fixed black thumbnails for `webm` videos by extracting an actual video frame for the thumbnail.
- Fixed the issue where `webm` videos did not show thumbnails.

### Improvements
- Unified the video playback experience so regular video formats, WebM, and AVI share the same window controls.
- The packaging flow now generates the application icon automatically from `icon/icon.png`.
