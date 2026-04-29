# 发包与发布规范（Flutter）

本文档用于约定 `fplayer-ff-mobile` 的标准发包流程、脚本行为和发布检查项。

## 1. 适用范围

- Windows 桌面发布包（zip）
- Android 安装包（apk）
- Android 上架包（aab）

## 2. 统一入口

统一使用脚本：`scripts/build_release.ps1`

示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -BuildName v1.2.0 -BuildVersionName 1.2.0 -BuildVersionNumber 120 -RunAnalyze -RunTest
```

## 3. 脚本行为约定（含前面更新）

### 3.1 构建行为

- 默认执行 `flutter pub get`
- 默认构建：
  - `flutter build windows --release`
  - `flutter build apk --release`
  - `flutter build appbundle --release`
- `windows/` 不存在时会自动执行 `flutter create --platforms=windows .`

### 3.2 版本注入

- 通过参数注入 Flutter 构建版本：
  - `-BuildVersionName` -> `--build-name`
  - `-BuildVersionNumber` -> `--build-number`

### 3.3 Android 签名行为

- 如果存在 `android/key.properties`，release 使用正式签名
- 如果不存在 `android/key.properties`，回退 debug 签名（仅内部测试）
- 正式对外分发或上架时，必须提供正式签名

### 3.4 质量门禁（可选）

- `-RunAnalyze`：构建前执行 `flutter analyze`
- `-RunTest`：构建前执行 `flutter test`

### 3.5 产物收集行为

产物会复制到 `dist/<BuildName或时间戳>/`，并使用统一命名：

- `fplayer-ff-mobile-windows.zip`
- `fplayer-ff-mobile-android.apk`
- `fplayer-ff-mobile-android.aab`

同时生成辅助文件：

- `checksums.txt`（SHA256）
- `release-notes-template.md`（发布说明模板）

## 4. 参数矩阵

- `-SkipWindows`：跳过 Windows 构建
- `-SkipAndroid`：跳过 Android 构建（APK + AAB）
- `-SkipApk`：Android 下跳过 APK
- `-SkipAab`：Android 下跳过 AAB
- `-BuildName <name>`：指定 `dist` 子目录名
- `-BuildVersionName <x.y.z>`：指定版本名
- `-BuildVersionNumber <n>`：指定版本号
- `-RunAnalyze`：启用 analyze
- `-RunTest`：启用 test

## 5. 推荐发布流程

1. 准备正式签名（`android/key.properties` + keystore）
2. 执行包含质量检查的完整构建
3. 检查 `dist/.../checksums.txt`
4. 填写 `dist/.../release-notes-template.md`
5. 对外发布：
   - Play：优先使用 `.aab`
   - 侧载：提供 `.apk`
   - Windows：提供 `.zip`

## 5.1 `build/` 与 `dist/` 目录职责

- `build/`：工具链构建目录（中间目录）
  - 由 Flutter/Gradle 自动生成
  - 包含缓存、临时文件和原始平台输出
  - 可通过 `flutter clean` 清理后重新生成
- `dist/`：发布目录（分发目录）
  - 由 `scripts/build_release.ps1` 生成
  - 每次构建独立子目录（`dist/<BuildName或时间戳>/`）
  - 仅存放可分发文件和发布辅助文件

## 5.2 成功判定标准

- 以 `dist/<构建目录>/` 为主判定
- 成功标准：
  - Windows 目标：存在 `fplayer-ff-mobile-windows.zip`
  - Android 侧载目标：存在 `fplayer-ff-mobile-android.apk`
  - Android 上架目标：存在 `fplayer-ff-mobile-android.aab`
  - 完整发布建议同时存在 `checksums.txt`

## 5.3 本地核对结果（当前仓库）

当前最近一次完整打包目录为 `dist/20260429-125543/`，包含：

- `fplayer-ff-mobile-windows.zip`
- `fplayer-ff-mobile-android.apk`
- `fplayer-ff-mobile-android.aab`
- `checksums.txt`
- `release-notes-template.md`

## 6. 常见命令

```powershell
# 全量构建（默认）
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1

# 上架版（推荐）
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -BuildName v1.2.0 -BuildVersionName 1.2.0 -BuildVersionNumber 120 -RunAnalyze -RunTest

# 仅 Android AAB
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1 -SkipWindows -SkipApk
```
