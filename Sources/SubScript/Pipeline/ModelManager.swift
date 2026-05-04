import Observation
@preconcurrency import Qwen3ASR
@preconcurrency import SpeechVAD
import AudioCommon
import Foundation

public protocol VADModelProtocol: @unchecked Sendable {
    func detectSpeech(audio: [Float], sampleRate: Int) -> [SpeechSegment]
}

extension SileroVADModel: VADModelProtocol {}
extension FireRedVADModel: VADModelProtocol {}

@Observable
@MainActor
final class ModelManager {
    static let shared = ModelManager()
    
    var isLoading = false
    var isReady   = false
    var loadError: String?
    var statusMessage: String = ""
    
    private(set) var asr: Qwen3ASRModel?
    private(set) var vad: VADModelProtocol?
    
    private var loadedSize: AppState.ASRModelSize?
    private var loadedPrecision: AppState.ASRPrecision?
    private var loadedVadType: AppState.VADModel?
    
    private init() {}
    
    enum ModelMode {
        case fast
        case quality
    }
    
    nonisolated private func log(_ message: String) {
        print("[ModelManager] \(message)")
        Task { @MainActor in
            ModelManager.shared.statusMessage = message
        }
    }
    
    func loadModels(
        mode: ModelMode = .quality,
        size: AppState.ASRModelSize = .small,
        precision: AppState.ASRPrecision = .bit4,
        vadType: AppState.VADModel = .silero
    ) async {
        log(String(localized: "model_log_loading_start").replacingOccurrences(of: "%@", with: size.rawValue).replacingOccurrences(of: "%@", with: precision.rawValue))
        
        if isReady, 
           loadedSize == size, 
           loadedPrecision == precision, 
           loadedVadType == vadType {
            log(String(localized: "model_log_ready"))
            return
        }
        
        if isReady {
            log(String(localized: "model_log_changed"))
            unloadModels()
        }
        
        isLoading = true
        loadError = nil
        
        do {
            let sizeTag = (size == .small) ? "0.6B" : "1.7B"
            let precisionTag = switch precision {
            case .bit4: "4bit"
            case .bit8: "8bit"
            case .bit16: "16bit"
            }
            
            let modelId = "aufklarer/Qwen3-ASR-\(sizeTag)-MLX-\(precisionTag)"
            log(String(localized: "model_log_asr_prep").replacingOccurrences(of: "%@", with: modelId))
            
            async let asrLoad = Qwen3ASRModel.fromPretrained(modelId: modelId)
            log(String(localized: "model_log_asr_loading"))
            
            async let vadLoad: VADModelProtocol? = {
                switch vadType {
                case .silero: 
                    log(String(localized: "model_log_vad_silero"))
                    return try await SileroVADModel.fromPretrained()
                case .fireRed: 
                    log(String(localized: "model_log_vad_firered"))
                    return try await FireRedVADModel.fromPretrained()
                }
            }()
            
            log(String(localized: "model_log_syncing"))
            let (loadedAsr, loadedVad) = try await (asrLoad, vadLoad)
            
            self.asr = loadedAsr
            self.vad = loadedVad
            
            self.loadedSize = size
            self.loadedPrecision = precision
            self.loadedVadType = vadType
            
            self.isReady = true
            log(String(localized: "model_log_success"))
        } catch {
            log(String(localized: "model_log_error").replacingOccurrences(of: "%@", with: error.localizedDescription))
            loadError = String(localized: "model_log_failed")
        }
        
        isLoading = false
    }
    
    func unloadModels() {
        asr = nil
        vad = nil
        isReady = false
        loadedSize = nil
        loadedPrecision = nil
        loadedVadType = nil
        statusMessage = ""
    }
}
