# magicallyEncircle

在 Mac 屏幕上用「魔法画笔」画出图案来触发快捷键、圈选复制/截图的菜单栏小工具。

- 按住 **Option + 鼠标左键拖动**即可在任意界面之上绘制发光的魔法线条
- 画出特定图案触发对应动作（撤销、复制、切换桌面、关闭窗口……）
- 圈选文本可复制、圈选区域可截图
- 支持多笔画图案（如叉号）、自定义图案与快捷键、图案播放演示

> 菜单栏常驻、无 Dock 图标（`LSUIElement`）。支持 macOS 14.7+ / Apple Silicon。

---

## 功能特性

### 魔法绘制
- 全局覆盖层（所有屏幕 / 所有空间 / 全屏应用之上）绘制跟随鼠标的魔法线条
- 带辉光、渐变、星尘粒子，松手后淡出
- **视觉风格**可切换（当前内置「白橙发光 · 星尘粒子」，架构上可继续扩展）

### 图案识别
- 基于 `$1 Unistroke Recognizer`（单笔）+ 逐笔贪心配对（支持多笔）
- 反向绘制、±10° 旋转容错；只需大致相似即可匹配
- 直线滑动单独按方向判定（← 后退 / → 前进 / ↑ 调度中心 / ↓ App 速览）
- **识别反馈 HUD**（可开关）：屏幕下方显示本次匹配结果与候选图案的相似度排名，便于调参

### 内置图案（动作）
| 动作 | 默认触发 | 说明 |
|---|---|---|
| 后退 / 前进 | ← / → 滑动 | 发送 ⌘[ / ⌘] |
| 调度中心 / App 速览 | ↑ / ↓ 滑动 | 系统级动作（见下） |
| 撤销 | 图案 `Z` | ⌘Z |
| 复制 | 图案 `C` | ⌘C |
| 粘贴 | 图案 `V` | ⌘V |
| 新建标签页 | 图案 `N` | ⌘T |
| 锁定屏幕 | 图案 `L` | 系统级动作 |
| 显示桌面 | （需自定义） | F11 / 系统级动作 |
| 关闭 | 图案 `X`（叉号，可多笔） | 动作可在通用设置里选择 |

每个内置图案都可**重新录制**自己的图案来覆盖默认触发，也可**恢复默认**。

> **系统级动作**（调度中心、App 速览、显示桌面、锁定屏幕、切换空间）不响应 App 合成的键盘事件，程序内部改走专用通道（`CoreDockSendNotification` / 合成 Dock 滑动手势等）来正确触发。

### 圈选操作（闭环图案）
- **画一个闭合圈 + 快速松手** → 复制圈内文本（优先用辅助功能 API 精确取字，取不到回退 Vision OCR）
- **画一个闭合圈 + 按住左键 1 秒** → 截图圈选区域并复制到剪贴板

### 多笔画图案
像「叉号」这类一笔画不好的图案，可分多笔绘制，最后合并为一个图案识别：
- **双击 Option（默认）**：单击 = 单笔（松左键识别）；双击（轻点一下再按住）= 多笔（松 Option 才识别）
- **单击 Option**（通用设置可切换）：按住 Option 即多笔
- 多笔期间笔画保持显示，识别后统一淡出
- 两种模式互斥，可在「通用设置 → 启用多笔画」切换

### 自定义图案
- 可录制、重命名、删除、绑定任意快捷键
- 播放按钮可**演示该图案的绘制过程**（使用当前视觉风格，速度可在通用设置里调 0.25×/0.5×/0.75×，默认 0.5×）

### 设置窗口
菜单栏 →「设置…」打开（600×450，可拖动/缩放，位置记忆）。左侧栏目：

- **通用设置**：启用魔法线条、显示识别反馈、关闭图案的动作、启用多笔画、图案播放速度、导入/导出图案
- **视觉风格**：切换线条外观
- **内置图案**：为每个动作录制图案 / 恢复默认（内嵌画布，可多笔）
- **自定义图案**：网格卡片（图案预览 + 名称 + 快捷键），支持播放、重命名、设置快捷键、删除
- **记录图案**：窗口内画布直接绘制并保存为自定义图案

### 导入 / 导出
- 导出自定义图案与内置覆盖为 JSON，可分享给他人
- 导入自动合并（重名自动加序号，快捷键一并导入）

---

## 基本操作

| 操作 | 效果 |
|---|---|
| 按住 Option + 左键拖动 | 绘制一条魔法线条 |
| 松左键 | 单笔模式：识别图案 |
| 双击 Option 再按住画多笔，松 Option | 多笔模式：合并识别 |
| 画闭合圈快松 | 复制圈内文本 |
| 画闭合圈按住 1 秒 | 截图圈选区域 |
| 菜单栏 ✨ 图标 | 打开菜单（设置、样式、记录、导入导出、退出） |

---

## 权限

首次使用需要授予：

- **辅助功能**：全局监听 Option + 左键、合成快捷键（必需）
- **屏幕录制**：圈选复制文本 / 圈选截图（首次用到时提示）

位置：系统设置 → 隐私与安全性 → 辅助功能 / 屏幕录制。授权后如遇问题，移除再重新添加本 App 即可。

---

## 构建与打包

```bash
# 本地编译（Debug，产物在 ./.build，不污染全局）
xcodebuild -project magicallyEncircle.xcodeproj -scheme magicallyEncircle \
  -configuration Debug -derivedDataPath ./.build build

# 打包 DMG
./scripts/build_dmg.sh              # 正常签名构建
UNSIGNED=1 ./scripts/build_dmg.sh   # 不签名（本机自用）
# 产物：.build/magicallyEncircle.dmg
```

分享给他人且不想弹 Gatekeeper 警告，需要 Developer ID 签名 + 公证（`notarytool` + `stapler`）。

---

## 项目结构

```
magicallyEncircle/
├── magicallyEncircleApp.swift     # SwiftUI App 入口（Settings 场景壳）
├── AppDelegate.swift              # 启动、状态栏菜单
├── MagicController.swift          # 核心协调器：覆盖层/输入/识别/动作/设置
├── InputMonitor.swift             # CGEventTap：拦截 Option+左键、双击检测、按键捕获
├── OverlayWindow.swift            # 全屏透明覆盖窗口
├── MagicCanvasView.swift          # 线条绘制、粒子、淡出、笔画固定
├── MagicStyle.swift               # 视觉风格
├── Gesture/                       # 识别引擎
│   ├── Geometry.swift             # 长度/包围盒/闭环/滑动方向
│   ├── GestureRecognizer.swift    # $1 + 多笔贪心匹配
│   ├── GestureTemplate.swift      # 内置图案模板
│   └── BuiltInGesture.swift       # 内置动作与默认触发
├── Actions/
│   ├── GestureAction.swift        # 动作与快捷键发送
│   ├── SystemHotkey.swift         # 系统级动作专用触发通道
│   ├── ScreenCaptureService.swift # 屏幕区域截取
│   └── TextExtractionService.swift# 圈选取字（AX + Vision OCR）
├── Model/                         # 数据与持久化
│   ├── CustomGesture.swift        # 自定义图案（支持多笔）+ 存储
│   ├── GesturePackage.swift       # 导入/导出格式
│   ├── GestureOverrideStore.swift # 内置图案覆盖
│   ├── CloseAction / MultiStrokeMode / PlaybackSpeed / KeyCodeNames
├── Playback/PatternPlayer.swift   # 图案播放
└── UI/
    ├── StatusMenuController.swift # 菜单栏菜单
    ├── SettingsWindowController.swift / SettingsView.swift  # 菜单窗口
    └── RecognitionHUD.swift       # 识别反馈浮层
```

---

## 已知限制 / 说明

- 使用私有框架（SkyLight / HIServices / login）触发系统级动作，已做动态查找与回退，但不保证未来 macOS 版本可用
- 系统级快捷键（如 Mission Control）是通过专用通道触发的；仅合成普通键盘事件对它们无效
- 「显示桌面」默认没有图案，需要自行录制或绑定快捷键
- 图案播放默认在**当前鼠标所在屏幕居中**演示（原始坐标可能已不在屏内）
