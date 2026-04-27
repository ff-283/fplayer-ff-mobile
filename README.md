# fplayer-ff-mobile

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
