import Foundation
import SwiftUI

struct BurnConfig: Codable, Equatable {
    // Video codec
    var videoCodec: VideoCodec = .h264
    
    // Quality (CRF or bitrate)
    var quality: QualityMode = .balanced
    var customCRF: Int = 23
    
    // Font settings
    var fontSize: Int = 24
    var fontName: String = "PingFang SC"
    var primaryColor: String = "&HFFFFFF"
    var outlineColor: String = "&H000000"
    var outlineWidth: Int = 2
    var shadowEnabled: Bool = true
    
    // Position
    var position: SubtitlePosition = .bottom
    
    // Output
    var outputFolder: URL?
    var outputFormat: OutputFormat = .mp4
    
    static var `default`: BurnConfig {
        BurnConfig()
    }
}

enum VideoCodec: String, CaseIterable, Codable {
    case h264 = "libx264"
    case h264_vt = "h264_videotoolbox"
    case hevc = "libx265"
    case hevc_vt = "hevc_videotoolbox"
    case av1 = "libaom-av1"
    case vp9 = "libvpx-vp9"
    case prores = "prores"
    
    var displayName: String {
        switch self {
        case .h264: return "H.264 (libx264)"
        case .h264_vt: return "H.264 (VideoToolbox)"
        case .hevc: return "H.265/HEVC (libx265)"
        case .hevc_vt: return "H.265/HEVC (VideoToolbox)"
        case .av1: return "AV1 (libaom)"
        case .vp9: return "VP9 (libvpx)"
        case .prores: return "ProRes"
        }
    }
    
    var supportsCRF: Bool {
        switch self {
        case .h264, .hevc, .av1, .vp9:
            return true
        case .h264_vt, .hevc_vt, .prores:
            return false
        }
    }
}

enum QualityMode: String, CaseIterable, Codable {
    case high = "高质量"
    case balanced = "平衡"
    case small = "小文件"
    case custom = "自定义"
    
    var defaultCrf: Int {
        switch self {
        case .high: return 18
        case .balanced: return 23
        case .small: return 28
        case .custom: return 23
        }
    }
    
    var bitrate: String {
        switch self {
        case .high: return "8000k"
        case .balanced: return "4000k"
        case .small: return "2000k"
        case .custom: return "4000k"
        }
    }
}

enum SubtitlePosition: String, CaseIterable, Codable {
    case bottom = "底部"
    case top = "顶部"
    case center = "居中"
    
    var assAlignment: Int {
        switch self {
        case .bottom: return 2
        case .top: return 8
        case .center: return 5
        }
    }
}

enum OutputFormat: String, CaseIterable, Codable {
    case mp4 = "MP4"
    case mov = "MOV"
    case mkv = "MKV"
    case webm = "WebM"
    
    var fileExtension: String {
        rawValue.lowercased()
    }
}
