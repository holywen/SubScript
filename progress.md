# SubScript 实现进度

> 原生 macOS 字幕生成工具 - 基于 Qwen3-ASR

## 项目状态

**当前阶段**: Phase 4 (Pro 功能) ✅ 完成

**最后更新**: 2026-04-30

**构建方式**: `./build.sh all`

---

## Phase 1 — 核心流水线验证 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| Package.swift 配置 | ✅ | swift-tools-version: 6.0, macOS 15.0+, speech-swift v0.0.12 |
| SubtitleSegment.swift | ✅ | 数据模型 + SRT/VTT 时间戳格式化 |
| TranscriptionJob.swift | ✅ | 任务状态 + Step 进度 |
| AudioExtractor.swift | ✅ | AVFoundation 音频提取 + 16kHz 重采样 |
| ModelManager.swift | ✅ | Qwen3ASRModel + SileroVADModel 单例 |
| SentenceSplitter.swift | ✅ | 标点断句 + 时间戳对齐 |
| TranscriptionPipeline.swift | ✅ | 流水线串联（修复片段提取bug） |
| SubScriptApp.swift | ✅ | 注入 ModelManager |
| 构建验证 | ✅ | `Build complete!` |

---

## Phase 2 — 基础 UI ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| AppState.swift | ✅ | 全局状态 + 导航 + 转写任务管理 |
| ExportService.swift | ✅ | SRT/VTT/TXT/ASS 导出 |
| HomeView.swift | ✅ | 拖拽区 + 文件选择 + 最近文件 |
| ProcessingView.swift | ✅ | 进度圈 + 步骤列表 + 取消 |
| ResultsView.swift | ✅ | 视频播放 + 字幕列表 + 编辑 |
| ExportView.swift | ✅ | 导出格式选择 + NSSavePanel |
| ContentView.swift | ✅ | 页面路由 + sheet 触发 |
| 构建验证 | ✅ | `Build complete!` |

---

## Phase 3 — 编辑器完善 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| VideoPlayerView 修复 | ✅ | MainActor 隔离修复 |
| 字幕 -> 视频跳转 | ✅ | onTapGesture 设置 playerCurrentTime |
| 视频 -> 字幕联动 | ✅ | onChange(activeSubtitleId) scrollTo |
| 内联编辑 | ✅ | 双击 TextField 替换 |
| 搜索过滤 | ✅ | searchText 过滤字幕 |
| 转写 pipeline 修复 | ✅ | 每次循环提取正确的片段数据 |
| 构建验证 | ✅ | `Build complete!` |

---

## Phase 3.2 — App Bundle 修复 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| App Bundle 创建 | ✅ | 创建 .app 包裹 |
| AppIcon.icns | ✅ | 转换 PNG 为 icns |
| mlx.metallib 打包 | ✅ | 复制到 Contents/MacOS |
| App Icon 更新 | ✅ | 使用 subscript_icon.png |
| arm64 架构 | ✅ | 仅支持 Apple Silicon |

---

## Phase 4 — Pro 功能 ✅
 
 | 任务 | 状态 | 说明 |
 |------|------|------|
 | 字幕烧录 (BurnService) | ✅ | 使用 bundled ffmpeg 硬编码字幕到视频 |
 | Burning 配置 (BurnConfig) | ✅ | 字体大小、颜色、描边宽度配置 |
 | Burning UI (BurnOptionsView) | ✅ | SwiftUI 配置面板 |
 | Progress View | ✅ | 实时进度显示 |
 | FFmpeg 打包 | ✅ | 内置带 libass 的 ffmpeg 二进制 |
 | Sandbox 关闭 | ✅ | 允许文件访问任意路径 |
 | 进度实时更新 | ✅ | `-progress pipe:1` 参数 |
 | Cancel 支持 | ✅ | 可以取消烧录 |
 | 视频格式过滤 | ✅ | 仅视频文件显示烧录按钮 |
 | 多编码器支持 | ✅ | H.264/H.265/AV1/VP9/VideoToolbox/ProRes |
 | ColorPicker 修复 | ✅ | 添加标签使选择器正常关闭 |
 | 进度显示修复 | ✅ | 从 0% 开始逐步增长 |
 | 关闭按钮 | ✅ | 设置和完成对话框添加 X 关闭按钮 |
 | 国际化 (i18n) | ✅ | 支持中英文，修复资源打包与状态 Key 映射 |
 | HomeView 恢复 | ✅ | 修复视图结构并添加「浏览文件」按钮 |
 
 ---


## 构建说明

### 环境要求

- macOS 15.0+ (Sonoma)
- Xcode 16+ (with Metal Toolchain)
- Apple Silicon (M1/M2/M3/M4)

### 快速构建

```bash
./build.sh all
```

### 分步构建

```bash
./build.sh setup         # 安装 Metal Toolchain
swift package resolve   # 解析依赖
./build.sh rebuild-metal # 编译 MLX metallib
./build.sh build        # 构建 release
./build.sh debug       # 构建 debug
./build.sh clean       # 清理
```

### 运行

```bash
open .build/release/SubScript
# 或
open .build/debug/SubScript
```

---

## 技术依赖

```
speech-swift
├── Qwen3ASR         v0.0.12  # ASR 推理
├── SpeechVAD         v0.0.12  # Silero VAD
└ SpeechUI         v0.0.12  # SwiftUI 组件

构建要求:
- swift-tools-version: 6.0
- 最低部署目标: macOS 15.0 (Sonoma)
- Xcode 16+ (with Metal Toolchain)
- Apple Silicon (M1/M2/M3/M4)
```

---

## 已知问题

1. **Assets.xcassets**: ✅ 已迁移到 SPM 标准位置 (Sources/SubScript/)
2. **entitlements**: ✅ 已创建 (SubScript/Resources/)
3. **App Icon**: ✅ 已配置Assets.xcassets/AppIcon.appiconset
4. **内存占用**: 10GB+ (模型加载是正常的)

---

## 下一步行动

**后续版本**：
1. StoreKit 2 购买流程
2. 本地翻译（Qwen3Chat）
3. 批量处理队列
4. 会议摘要（Qwen3Chat）