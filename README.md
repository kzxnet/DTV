---

# LibreTV 应用

一个基于 **Flutter** 开发的智能电视/机顶盒视频播放应用，支持多种视频格式和网络流媒体播放，专为电视遥控器操作优化。

---

## 📺 功能特性

- 🎬 **多格式支持**：播放 MP4、HLS、MKV 等主流视频格式
- 📺 **遥控器优化**：专为电视/机顶盒遥控器操作设计
- 🔍 **快速导航**：支持选集、章节跳转
- ⏯️ **播放控制**：播放/暂停、快进/快退、进度条拖动
- 🔉 **音量调节**：支持系统音量控制
- 🌙 **屏幕常亮**：播放时防止设备休眠
- 📡 **API 聚合**：支持苹果CMS V10 API 视频源

---

## 🛠️ 技术栈

| 技术/组件       | 用途                     |
|----------------|--------------------------|
| Flutter 3.x    | 跨平台应用开发框架        |
| Dart 3.x       | 编程语言                 |
| `video_player` | 核心视频播放功能         |
| `chewie`       | 播放器 UI 控件           |
| `wakelock_plus`| 屏幕常亮控制             |

---

## 📡 数据接口

本应用使用 **苹果CMS V10 API** 作为视频源：

```dart
// 示例：搜索视频
const apiUrl = 'https://cms-api.aini.us.kg/api/search?wd=新三国';
```

### 主要 API 端点
| 功能       | 接口路径                     | 参数               |
|-----------|-----------------------------|--------------------|
| 视频搜索   | `/api/search`               | `wd=[关键词]`      |
| 视频详情   | `/api/video/[视频ID]`       | -                  |
| 分类列表   | `/api/category/[分类ID]`    | `page=[页码]`      |

---

## 📜 开源协议 (MIT License)

```text
Copyright (c) 2023 LibreTV Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## ⚠️ 免责声明

1. **技术演示用途**：本应用仅为 Flutter 开发技术演示，不提供任何视频内容。
2. **内容来源**：所有视频内容均来自第三方 API 接口，开发者无法控制其内容合法性。
3. **无存储功能**：应用本身不存储、不缓存任何视频资源。
4. **用户责任**：使用者应遵守所在地区法律法规，禁止传播违法内容。
5. **责任豁免**：因使用本应用产生的任何法律纠纷，开发者不承担任何责任。

---

## 🛠️ 开发环境

```bash
# 1. 安装依赖
flutter pub get

# 2. 运行应用（连接设备或模拟器）
flutter run

# 3. 构建APK（Android）
flutter build apk --release
```

**系统要求**：
- Flutter SDK ≥ 3.0
- Dart ≥ 3.0
- Android Studio / VS Code

---

## 📚 参考资料

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言指南](https://dart.dev/guides)
- [video_player 插件文档](https://pub.dev/packages/video_player)
- [苹果CMS API 文档]()
- [TV 应用设计规范](https://developer.android.com/design/tv)

---

> ✨ 欢迎贡献代码！请提交 Pull Request 到 `dev` 分支。  
> 🐞 问题反馈：<laopaoer@protonmail.com>

```

### 版本亮点
1. **结构化排版**：使用 Markdown 表格和模块化分区
2. **法律合规**：包含完整的 MIT 协议和免责声明
3. **开发友好**：清晰的 API 文档和构建命令
4. **国际化**：纯中文版本（可轻松扩展多语言）

如需添加截图或 GIF 演示，建议在 `## 功能特性` 部分下方插入：
```markdown
## 🖼️ 应用截图
| 主界面 | 播放页 | 搜索页 |
|--------|--------|--------|
| ![主界面](<img width="1440" alt="image" src="https://github.com/user-attachments/assets/4154a8c6-42ca-4e0a-95c9-e99d337139fb" />) | ![播放页](<img width="1440" alt="image" src="https://github.com/user-attachments/assets/96a5b846-a27e-409a-bf7a-105b581490ed" />) | ![搜索页](<img width="1440" alt="image" src="https://github.com/user-attachments/assets/d85417a3-f7ea-4cea-9d34-eb17702fffc6" />
) |
```
