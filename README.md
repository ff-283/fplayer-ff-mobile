# fplayer-ff-mobile

<p align="center">
  <img src="./doc/img/icon.png" alt="fplayer-ff-mobile icon" width="180">
</p>

`fplayer-ff-mobile` 是一个用于局域网播放服务流（HLS/HTTP-FLV/RTMP）的 Flutter 客户端。

## 技术栈

客户端采用 **Flutter** 实现跨平台 UI 与业务逻辑，与 `fplayer-ff-service` 的 Gateway 联调时通过 HTTP 拉取解析后的播放地址。各层技术如下。

- **语言与框架**：**Dart 3.3+**、**Flutter**（声明式 UI、Material 组件）。
- **媒体播放**：[media_kit](https://pub.dev/packages/media_kit) 系列（`media_kit`、`media_kit_video`、`media_kit_libs_video`），基于 libmpv 等原生库，用于 HLS / HTTP-FLV / RTMP 等拉流与解码渲染。
- **网络**：`http` 包，请求 Gateway（例如 `GET /api/v1/streams/resolve`）获取 HLS、HTTP-FLV、RTMP 等地址。
- **目标平台**：**Android**、**Windows** 桌面；**Web**（浏览器侧以 HLS 兼容性为佳）。
- **工程工具**：`flutter_lints` 静态分析、`flutter_launcher_icons` 生成 Android 应用图标；发布脚本见 `scripts/build_release.ps1`。

## 功能

### 本项目可独立提供的能力

- **多协议拉流播放**：支持 HLS / HTTP-FLV / RTMP 播放，覆盖常见局域网流媒体消费场景。
- **双模式播放入口**：提供“服务地址模式”和“直接 URL 模式”，既可标准化接入，也可用于快速临时调试。
- **跨平台客户端形态**：可运行在 Android、Windows 与 Web（推荐 HLS），满足移动端和桌面端播放需求。
- **发布流程标准化**：内置统一打包脚本，可产出 APK / AAB / Windows 包并附带校验信息，便于测试分发与正式发布。

### 与其他项目的联合功能

- **与 `fplayer-ff-service` 联动（推荐）**：通过调用 Gateway 的 `resolve` 接口自动获取真实播放地址，避免手工处理端口漂移与协议差异。
- **与 `fplayer-ff-desktop` 联动（观看端）**：desktop 无论是单独 P2P 推流，还是接入 service 后的编排推流，mobile 均可作为移动观看端接入播放。
- **三端协同链路**：desktop 生产流 -> service 编排并暴露播放地址 -> mobile 拉流播放，形成完整的局域网流媒体消费路径。

## 1. 快速启动

1. 确保 Flutter SDK 可用（已加入 PATH）
2. 安装依赖并启动：

   ```bash
   flutter pub get
   flutter run
   ```

## 1.1 应用图标（Android）

当前已配置使用 `doc/img/icon.png` 作为 Android 应用图标。首次或图标变更后请执行：

```bash
flutter pub get
dart run flutter_launcher_icons
```

## 1.2 发包（Windows + Android，上架增强版）

已提供一键打包脚本：`scripts/build_release.ps1`

完整规范文档见：`doc/release-packaging.md`

在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1
```

构建完成后产物会集中在 `dist/<时间戳>/`（或你指定的 `BuildName`）：

- `fplayer-ff-mobile-windows.zip`（Windows 发布包）
- `fplayer-ff-mobile-android.apk`（Android 安装包）
- `fplayer-ff-mobile-android.aab`（Google Play 上架包）
- `checksums.txt`（SHA256 校验文件）
- `release-notes-template.md`（发布说明模板）

可选参数：

```powershell
# 自定义产物目录名
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -BuildName v1.0.0

# 仅打 Windows
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -SkipAndroid

# 仅打 Android
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -SkipWindows

# 指定 Flutter 版本号（推荐用于正式发布）
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -BuildVersionName 1.2.0 -BuildVersionNumber 120

# 仅产出 AAB（上架常用）
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -SkipWindows -SkipApk

# 构建前运行 analyze / test
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -RunAnalyze -RunTest
```

### 发包行为说明（本次已统一）

- 默认产出：Windows zip + Android apk + Android aab
- 默认会执行 `flutter pub get`
- 可通过参数控制是否跳过某一平台或某一种 Android 产物
- 会自动生成 `checksums.txt` 和 `release-notes-template.md`

### `build` 和 `dist` 的区别

- `build/`：Flutter 和 Gradle 的**中间构建目录**，包含编译缓存、临时输出与平台原始产物路径（例如 `build/app/...`、`build/windows/...`）
- `dist/`：脚本整理后的**发布目录**，每次打包生成一个独立子目录，放对外分发文件（zip/apk/aab）和校验文件

### 如何判断打包是否成功

- 推荐以 `dist/<构建目录>/` 下是否出现目标文件为准
- 至少应看到你需要的平台产物（例如 `.apk`、`.aab`、`windows.zip`）
- 同时建议检查 `checksums.txt` 已生成

### 当前已生成产物位置（本地核对）

最近一次完整产物目录：

- `dist/20260429-125543/fplayer-ff-mobile-windows.zip`
- `dist/20260429-125543/fplayer-ff-mobile-android.apk`
- `dist/20260429-125543/fplayer-ff-mobile-android.aab`
- `dist/20260429-125543/checksums.txt`
- `dist/20260429-125543/release-notes-template.md`

### Android 正式签名（上架/外发建议）

默认情况下，如果 `android/key.properties` 不存在，会使用 debug 签名（仅适合内部测试）。

如需正式签名：

1. 复制 `android/key.properties.example` 为 `android/key.properties`
2. 填入你的 keystore 信息
3. 重新执行打包脚本

## 2. 使用方式

应用内提供两种模式：

- `服务地址模式`（推荐）
- `直接 URL 模式`

### 2.1 服务地址模式（推荐）

适用于与 `fplayer-ff-service` 联动，使用方式与 desktop 一致。

1. 在 service 中先创建流（app/stream）
2. mobile 选择 `服务地址模式`
3. 填写：
   - `Service Gateway URL`（例如 `http://192.168.5.53:9000`）
   - `App`（如 `live`）
   - `Stream`（如 `stream001`）
4. 选择协议（`HLS` / `HTTP-FLV` / `RTMP`）
5. 点击 `播放`

mobile 会自动调用：

- `GET /api/v1/streams/resolve?app=...&stream=...`

并从返回结果读取对应地址后播放：

- HLS: `playHls` 或 `playUrls.hls`
- HTTP-FLV: `playHttpFlv`
- RTMP: `playUrls.rtmp`

### 2.2 直接 URL 模式

适用于你已拿到完整 FLV 地址时，直接手输播放，例如：

```text
http://192.168.5.53:8080/live/stream001.flv
```

## 3. 为什么推荐服务地址模式

- 不需要手工猜测或固定端口
- service 端口可能动态变化（8080 被占用时会自动切换）
- 总是以 service 实时返回的 `playHttpFlv` 为准

## 4. 常见问题

### 4.1 播放无画面/连接失败

请依次检查：

1. 手机与 service 是否在同一局域网（或可路由互通）
2. `http://<gateway-host>:<gateway-port>/healthz` 是否可达
3. `app/stream` 是否与 service 创建流一致
4. 防火墙是否放行 gateway 端口与媒体端口

### 4.2 Web(Chrome) 下播放建议

- Web 端优先使用 `HLS`
- `HTTP-FLV/RTMP` 在 Web 环境兼容性较差，可能出现“连接成功但无画面”

### 4.2 页面报 RenderFlex overflow

当前版本已改为可滚动布局；如仍出现，请执行：

```bash
flutter clean
flutter pub get
flutter run
```

## 5. 备注

- Android Manifest 已开启 cleartext HTTP（局域网测试）
- 建议优先使用 service UI 中给出的可复制信息进行联调
