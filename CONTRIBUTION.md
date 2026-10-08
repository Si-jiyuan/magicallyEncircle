# 贡献指南（Contributing）

感谢你对 magicallyEncircle 感兴趣！欢迎提交 Issue 与 Pull Request。

## 环境要求

- macOS **14.7+**（Apple Silicon）
- **Xcode 16+**（Swift 5）
- 无需 Homebrew、无第三方依赖

## 本地构建与运行

```bash
# 编译（产物落在项目内 ./.build，避免污染全局 DerivedData）
xcodebuild -project magicallyEncircle.xcodeproj -scheme magicallyEncircle \
  -configuration Debug -derivedDataPath ./.build build

# 打包 DMG
./scripts/build_dmg.sh              # 正常签名构建
UNSIGNED=1 ./scripts/build_dmg.sh   # 不签名（本机自用）
```

也可直接用 Xcode 打开 `magicallyEncircle.xcodeproj` 后 `Cmd+R`。

> 运行需要授予「辅助功能」权限；圈选复制/截图需要「屏幕录制」；「共享」需要「自动化」权限。

## 代码结构

```
magicallyEncircle/
├── MagicController.swift   核心协调器（覆盖层 / 输入 / 识别 / 动作 / 设置）
├── InputMonitor.swift      CGEventTap：拦截 Option+左键、多笔检测、按键捕获
├── MagicCanvasView.swift   线条绘制、粒子、淡出、笔画固定
├── Gesture/                识别引擎（$1 + 多笔贪心匹配）与内置图案
├── Actions/                动作执行、系统快捷键、截图、取字、共享
├── Model/                  数据模型与持久化（UserDefaults）
├── Playback/               图案播放
└── UI/                     菜单栏菜单、设置窗口、识别反馈 HUD
```

### 常见扩展点

- **新增视觉风格**：在 `MagicStyle.swift` 增加 case，并补全 `glowColor` / `particleColors`（菜单与设置会自动列出）
- **新增内置图案**：在 `BuiltInGesture.swift` 的 `all` 中追加一条，并在 `GestureAction.swift` 增加对应动作
- **持久化**：所有数据存 `UserDefaults`，键名以 `magicallyEncircle.` 开头

## 提交规范

本仓库提交信息采用「前缀 + 简短中文描述」的形式，例如：

```
add: 新增 XXX 功能
fix: 修复 XXX 问题
edit: 优化 XXX
```

请保持一次提交聚焦一件事，并在 PR 描述里说明动机与验证方式。

## Pull Request 流程

1. Fork 并基于 `main` 新建分支
2. 保证 `xcodebuild ... build` 通过（不要引入新的编译错误）
3. 如有界面变更，附上截图或录屏
4. 描述清楚改动点、影响范围与测试方法

## 注意事项

- 本 App **关闭了 App Sandbox**，并使用若干私有框架（SkyLight / HIServices / login）——请在实现时保持「动态查找 + 失败回退」，不要硬依赖私有符号
- 涉及全局输入拦截、合成事件、截图时，务必保持最小影响，并给出清晰的权限引导
- **不要提交任何密钥、令牌或隐私数据**（本项目全部数据仅存本地）
- 不要提交 `.build/`、`DerivedData/`、`xcuserdata/` 等本地产物（已在 `.gitignore` 中忽略）

## 安全问题

如发现安全问题，请勿直接开公开 Issue，按 [SECURITY.md](SECURITY.md) 的方式私下报告。
