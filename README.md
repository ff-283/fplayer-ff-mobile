# fplayer-ff-mobile

<p align="center">
  <img src="./doc/img/icon.png" alt="fplayer-ff-mobile icon" width="180">
</p>

`fplayer-ff-mobile` 是一个用于局域网播放服务流（HLS/HTTP-FLV/RTMP）的 Flutter 客户端。

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
