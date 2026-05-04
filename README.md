# SubScript

> 原生 macOS 字幕生成工具 - 基于 Qwen3-ASR

最后更新: 2026-04-30

从视频/音频文件自动生成字幕，完全本地运行。核心引擎使用 Qwen3-ASR（中文识别质量优于 Whisper），目标用户为中文 YouTuber、播客创作者、会议记录人员。

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-blue)
![Architecture](https://img.shields.io/badge/Apple-Silicon-M1%2FM2%2FM3%2FM4-blue)

---

## 产品特性

- **零 Python 依赖** - 全部 Swift 原生实现
- **Apple Silicon 优先** - MLX 推理，Metal GPU 加速
- **单例模型** - 全局只加载一份 ASR 模型
- **流式 UI** - 识别结果逐条推送
- **字幕烧录** - 硬编码字幕到视频（支持 H.264/H.265/AV1/VP9/ProRes/VideoToolbox）
- **多格式导出** - 支持 SRT, VTT, TXT, ASS, SSA, SBV, CSV, LRC, TTML 导出
- **国际化支持** - 完整支持中文与英文界面

---

## 技术架构

### 技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 语言 | Swift | 6.0+ |
| UI 框架 | SwiftUI + AppKit | macOS 15.0+ |
| 并发模型 | Swift Structured Concurrency | async/await + Actor |
| 包管理 | Swift Package Manager | - |

### 核心依赖

| 模块 | 说明 |
|------|------|
| **Qwen3ASR** | ASR 推理（Qwen3-ASR-0.6B / 1.7B） |
| **SpeechVAD** | 语音活动检测（Silero VAD） |
| **SpeechUI** | SwiftUI 音频组件 |
| **AudioCommon** | 共享音频协议和工具 |
| **FFmpeg** | 字幕烧录（bundled 二进制） |

### 音频处理

使用系统框架，无第三方依赖：
- `AVFoundation` - 音频提取、格式转换、视频播放
- `AVAudioConverter` - 重采样（任意采样率 → 16kHz mono）

### 项目结构

```
SubScript/
├── project.yml                # XcodeGen 配置
├── Package.swift            # SPM 配置
├── build.sh                 # 构建脚本
│
├── Sources/SubScript/
│   ├── SubScriptApp.swift     # @main 入口
│   ├── ContentView.swift      # 页面路由
│   │
│   ├── Models/
│   │   ├── SubtitleSegment.swift    # 字幕数据模型
│   │   └── TranscriptionJob.swift   # 任务状态模型
│   │
│   ├── Pipeline/                     # 核心业务逻辑
│   │   ├── ModelManager.swift       # 单例模型管理
│   │   ├── AudioExtractor.swift     # 音频提取 actor
│   │   ├── TranscriptionPipeline.swift # 转写流水线
│   │   └── SentenceSplitter.swift   # 断句 + 时间戳对齐
│   │
│   ├── State/
│   │   └── AppState.swift           # @Observable 全局状态
│   │
│   ├── Services/
│   │   ├── ExportService.swift     # SRT/VTT/TXT/ASS 导出
│   │   └── BurnService.swift        # 字幕烧录
    │   │
    │   ├── Store/
    │   │   └── BurnConfig.swift       # 烧录配置模型
    │   │
    │   └── Views/
│       ├── HomeView.swift          # 首页：拖拽区
│       ├── ProcessingView.swift    # 进度页
│       ├── ResultsView.swift      # 结果页 + 字幕编辑器 + 烧录按钮
│       ├── ExportView.swift       # 导出面板
│       ├── BurnOptionsView.swift # 烧录配置
│       └── BurnProgressView.swift  # 烧录进度
│
├── Sources/SubScript/Resources/
│   └── Binaries/
│       └── ffmpeg                 # 内置 ffmpeg (带 libass)
│
└── progress.md                    # 开发进度跟踪
```

---

## 构建流程

### 环境要求

- **macOS 15.0+** (Sonoma)
- **Xcode 16+** (with Metal Toolchain)
- **Apple Silicon** (M1/M2/M3/M4)

### 快速构建

```bash
./build.sh all
```

这将自动完成：
1. 安装 Metal Toolchain (~688MB)
2. 解析 SPM 依赖
3. 编译 MLX Metal shader library
4. 编译 SubScript

### 分步构建

```bash
# 1. 安装 Metal Toolchain
./build.sh setup

# 2. 解析依赖
swift package resolve

# 3. 仅编译 metallib
./build.sh rebuild-metal

# 4. 构建 release 版本
./build.sh build

# 5. 构建 debug 版本
./build.sh debug

# 6. 清理构建产物
./build.sh clean
```

### 运行

```bash
# debug 版本
.open .build/debug/SubScript

# release 版本
.open .build/release/SubScript
```

---

## 项目管理

项目使用 **XcodeGen** 管理，根目录有 `project.yml`。

### 规则

- 新增任何 `.swift` 文件后，必须运行 `xcodegen generate` 重新生成项目
- 不得手动编辑 `.xcodeproj` 内的任何文件
- 新的 SPM 依赖在 `project.yml` 的 `packages` 和 `dependencies` 里添加
- 目录结构变化同步更新 `project.yml` 的 `sources` 配置

### XcodeGen 命令

```bash
# 安装 XcodeGen
brew install xcodegen

# 重新生成项目
xcodegen generate

# 用 Xcode 打开
open SubScript.xcodeproj
```

---

## 使用说明

### 测试流程

1. **启动 App** → 打开 HomeView（拖拽区）
2. **拖入视频** → MP4/MOV/MP3/M4A/WAV/AAC
3. **等待处理** → ProcessingView 显示进度
4. **查看结果** → ResultsView 显示视频 + 字幕
5. **烧录字幕**（可选）→ 点击烧录按钮，硬编码字幕到视频
6. **导出** → ExportView 选择格式

### 支持的格式

| 输入 | 支持的操作 |
|------|------|
| MP4 | 字幕识别、烧录、导出 |
| MOV | 字幕识别、烧录、导出 |
| M4V | 字幕识别、烧录、导出 |
| MP3 | 字幕识别、导出 |
| M4A | 字幕识别、导出 |
| WAV | 字幕识别、导出 |
| AAC | 字幕识别、导出 |

> 注意：烧录功能仅适用于视频文件（MP4/MOV/M4V），音频文件不支持烧录。

### 导出格式

- **SRT** - 通用字幕
- **VTT** - Web 字幕
- **TXT** - 纯文本
- **ASS/SSA** - 高级样式
- **SBV** - SubViewer 格式
- **CSV** - 表格格式
- **LRC** - 歌词格式
- **TTML** - Timed Text 格式

### 烧录选项

| 选项 | 说明 |
|------|------|
| 编码器 | H.264、H.265/HEVC、AV1、VP9、ProRes、VideoToolbox |
| 质量 | 高质量(CRF 18)、平衡(CRF 23)、小文件(CRF 28)、自定义 |
| 字体大小 | 12-72pt |
| 字幕颜色 | 可选 (ColorPicker) |
| 描边颜色 | 可选 (ColorPicker) |
| 描边宽度 | 0-5px |
| 阴影 | 启用/禁用 |
| 位置 | 底部/顶部/居中 |
| 输出格式 | MP4/MOV/MKV/WebM |

---

## 已知问题

1. **首次运行慢** - 需要下载模型 (~1-2GB)，缓存在 `~/Library/Caches/qwen3-speech/`
2. **Assets.xcassets** - 需要从原位置迁移到 SPM 标准位置

---

## 开发进度

| 阶段 | 状态 |
|------|------|
| Phase 1: 核心流水线验证 | ✅ 完成 |
| Phase 2: 基础 UI | ✅ 完成 |
| Phase 3: 编辑器完善 | ✅ 完成 |
| Phase 3.1: 编辑器 Bugfix | ✅ 完成 |
| Phase 4: Pro 功能 | ✅ 完成（字幕烧录） |

详见 [progress.md](./progress.md)

---

## 开源致谢

本 App 基于以下开源项目构建，遵循各自许可证：

| 项目 | 版权 | 许可证 |
|------|------|--------|
| Qwen3-ASR | © Alibaba Cloud | Apache License 2.0 |
| speech-swift | © soniqo | MIT License |
| Apple MLX | © Apple Inc. | MIT License |
| Silero VAD | © Silero Team | MIT License |
| FFmpeg | © FFmpeg Team | LGPL/GPL |

---

## 许可证

Apache License 2.0 - See LICENSE file for details