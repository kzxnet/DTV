# LibreTV 应用

一个基于Flutter开发的智能电视/机顶盒视频播放应用。

## 功能特性

- 🎬 支持多种视频格式的网络流媒体播放
- 📺 专为电视遥控器操作优化
- 🔍 视频选集快速导航
- ⏯️ 播放控制（播放/暂停、快进/快退）
- 🔉 音量调节功能
- 🌙 播放时保持屏幕常亮
- 📡 支持苹果CMS V10 API视频源聚合

## 技术栈

- Flutter 3.x
- Dart 3.x
- video_player 插件
- chewie 播放器UI组件
- wakelock_plus 屏幕常亮控制

## 数据接口

本应用使用苹果CMS V10 API作为视频源：
```dart
// 示例搜索接口
const apiUrl = 'https://cms-api.aini.us.kg/api/search?wd=新三国';