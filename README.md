# SubScript

> Native macOS subtitle generation tool - powered by Qwen3-ASR

Last updated: 2026-05-04

Automatically generate subtitles from video/audio files, fully local. Uses Qwen3-ASR (Chinese recognition quality superior to Whisper), targeting Chinese YouTubers, podcast creators, and meeting note-takers.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-blue)
![Architecture](https://img.shields.io/badge/Apple-Silicon-M1%2FM2%2FM3%2FM4-blue)

---

## Features

- **Zero Python dependencies** - All native Swift implementation
- **Apple Silicon first** - MLX inference, Metal GPU acceleration
- **Singleton model** - Global ASR model loaded only once
- **Streaming UI** - Recognition results pushed line by line
- **Subtitle burning** - Hard-code subtitles to video (supports H.264/H.265/AV1/VP9/ProRes/VideoToolbox)
- **Multi-format export** - Supports SRT, VTT, TXT, ASS, SSA, SBV, CSV, LRC, TTML export
- **Internationalization** - Full Chinese and English UI support

---

## Technical Architecture

### Tech Stack

| Component | Technology | Version |
|------|------|------|
| Language | Swift | 6.0+ |
| UI Framework | SwiftUI + AppKit | macOS 15.0+ |
| Concurrency Model | Swift Structured Concurrency | async/await + Actor |
| Package Manager | Swift Package Manager | - |

### Core Dependencies

| Module | Description |
|------|------|
| **Qwen3ASR** | ASR inference (Qwen3-ASR-0.6B / 1.7B) |
| **SpeechVAD** | Voice activity detection (Silero VAD) |
| **SpeechUI** | SwiftUI audio components |
| **AudioCommon** | Shared audio protocols and utilities |
| **FFmpeg** | Subtitle burning (bundled binary) |

### Audio Processing

Uses system frameworks, no third-party dependencies:
- `AVFoundation` - Audio extraction, format conversion, video playback
- `AVAudioConverter` - Resampling (any sample rate → 16kHz mono)

### Project Structure

```
SubScript/
├── project.yml                # XcodeGen configuration
├── Package.swift            # SPM configuration
├── Makefile                 # Build script
│
├── Sources/SubScript/
│   ├── SubScriptApp.swift     # @main entry point
│   ├── ContentView.swift      # Page routing
│   │
│   ├── Models/
│   │   ├── SubtitleSegment.swift    # Subtitle data model
│   │   └── TranscriptionJob.swift   # Task status model
│   │
│   ├── Pipeline/                     # Core business logic
│   │   ├── ModelManager.swift       # Singleton model manager
│   │   ├── AudioExtractor.swift     # Audio extraction actor
│   │   ├── TranscriptionPipeline.swift # Transcription pipeline
│   │   └── SentenceSplitter.swift   # Sentence splitting + timestamp alignment
│   │
│   ├── State/
│   │   └── AppState.swift           # @Observable global state
│   │
│   ├── Services/
│   │   ├── ExportService.swift     # SRT/VTT/TXT/ASS export
│   │   └── BurnService.swift        # Subtitle burning
│   │
│   ├── Store/
│   │   └── BurnConfig.swift       # Burn config model
│   │
│   └── Views/
│       ├── HomeView.swift          # Home: drag & drop area
│       ├── ProcessingView.swift    # Progress page
│       ├── ResultsView.swift      # Results + subtitle editor + burn button
│       ├── ExportView.swift       # Export panel
│       ├── BurnOptionsView.swift # Burn options
│       └── BurnProgressView.swift  # Burn progress
│
├── Sources/SubScript/Resources/
│   └── Binaries/
│       └── ffmpeg                 # Bundled ffmpeg (with libass)
│
└── progress.md                    # Development progress tracking
```

---

## Build Process

### Requirements

- **macOS 15.0+** (Sonoma)
- **Xcode 16+** (with Metal Toolchain)
- **Apple Silicon** (M1/M2/M3/M4)

### Quick Build

```bash
make bundle
```

This will automatically:
1. Install Metal Toolchain (~688MB)
2. Resolve SPM dependencies
3. Compile MLX Metal shader library
4. Compile SubScript

### Run

```bash
# Open release version
open .build/release/SubScript.app
```

---

## Project Management

Project managed with **XcodeGen**, root directory has `project.yml`.

### Rules

- After adding any `.swift` file, must run `xcodegen generate` to regenerate project
- Must not manually edit any files in `.xcodeproj`
- New SPM dependencies should be added in `project.yml` under `packages` and `dependencies`
- Directory structure changes should be synced to `project.yml` `sources` config

---

## Usage

### Workflow

1. **Launch App** → Open HomeView (drag & drop area)
2. **Drag in video** → MP4/MOV/MP3/M4A/WAV/AAC
3. **Wait for processing** → ProcessingView shows progress
4. **View results** → ResultsView shows video + subtitles
5. **Burn subtitles** (optional) → Click burn button, hard-code subtitles to video
6. **Export** → ExportView select format

### Supported Formats

| Input | Supported Operations |
|------|------|
| MP4 | Recognition, burning, export |
| MOV | Recognition, burning, export |
| M4V | Recognition, burning, export |
| MP3 | Recognition, export |
| M4A | Recognition, export |
| WAV | Recognition, export |
| AAC | Recognition, export |

> Note: Burning only works for video files (MP4/MOV/M4V), audio files do not support burning.

### Export Formats

- **SRT** - Standard subtitles
- **VTT** - Web subtitles
- **TXT** - Plain text
- **ASS/SSA** - Advanced styling
- **SBV** - SubViewer format
- **CSV** - Spreadsheet format
- **LRC** - Lyrics format
- **TTML** - Timed Text format

### Burn Options

| Option | Description |
|------|------|
| Encoder | H.264, H.265/HEVC, AV1, VP9, ProRes, VideoToolbox |
| Quality | High quality (CRF 18), Balanced (CRF 23), Small file (CRF 28), Custom |
| Font size | 12-72pt |
| Subtitle color | Optional (ColorPicker) |
| Stroke color | Optional (ColorPicker) |
| Stroke width | 0-5px |
| Shadow | Enable/Disable |
| Position | Bottom/Top/Center |
| Output format | MP4/MOV/MKV/WebM |

---

## Known Issues

1. **Slow first run** - Requires model download (~1-2GB), cached in `~/Library/Caches/qwen3-speech/`
2. **Assets.xcassets** - Needs migration from original location to SPM standard location

---

## Development Progress

| Phase | Status |
|------|------|
| Phase 1: Core pipeline verification | ✅ Complete |
| Phase 2: Basic UI | ✅ Complete |
| Phase 3: Editor improvements | ✅ Complete |
| Phase 3.1: Editor Bugfix | ✅ Complete |
| Phase 4: Pro features | ✅ Complete (subtitle burning) |

See [progress.md](./progress.md) for details.

---

## Open Source Credits

This app is built on the following open source projects, following their respective licenses:

| Project | Copyright | License |
|------|------|--------|
| Qwen3-ASR | © Alibaba Cloud | Apache License 2.0 |
| speech-swift | © soniqo | MIT License |
| Apple MLX | © Apple Inc. | MIT License |
| Silero VAD | © Silero Team | MIT License |
| FFmpeg | © FFmpeg Team | LGPL/GPL |

---

## License

Apache License 2.0 - See LICENSE file for details