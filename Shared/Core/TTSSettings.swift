import Foundation
import AVFoundation

enum TTSEngine: String, Codable, CaseIterable, Identifiable {
    case system, openai
    var id: String { rawValue }
    var title: String { self == .system ? "系统语音(离线)" : "OpenAI 云端语音" }
}

struct TTSConfig: Codable, Equatable {
    var engine: TTSEngine = .system
    var zhVoice = ""            // AVSpeechSynthesisVoice.identifier,空 = 系统默认
    var enVoice = ""
    var speed: Double = 1.0     // 0.5x ~ 1.5x
    var baseURL = "https://api.openai.com/v1"
    var model = "gpt-4o-mini-tts"
    var voice = "alloy"
    var apiKey = ""             // 留空则沿用 OpenAI 兼容接口的 LLM Key

    static let cloudVoices = ["alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer"]
    static let cloudModels = ["gpt-4o-mini-tts", "tts-1", "tts-1-hd"]
}

@MainActor
final class TTSSettings: ObservableObject {
    static let shared = TTSSettings()
    private let defaultsKey = "tts.config"
    var onChange: ((TTSConfig) -> Void)?

    @Published var config: TTSConfig {
        didSet { persist(); onChange?(config) }
    }

    private init() {
        var c = TTSConfig()
        if let d = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(TTSConfig.self, from: d) { c = saved }
        c.apiKey = Keychain.get("tts")
        config = c
    }

    func apply(remote: TTSConfig) {
        let cb = onChange
        onChange = nil
        config = remote
        onChange = cb
    }

    /// 云端语音实际使用的 Key:优先独立 Key,否则沿用 OpenAI 兼容 LLM 的 Key
    var effectiveCloudKey: String {
        if !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty { return config.apiKey }
        let llm = AppSettings.shared.config
        return llm.provider == .openai ? llm.apiKey : ""
    }

    private func persist() {
        var c = config
        Keychain.set(c.apiKey, for: "tts")
        c.apiKey = ""
        if let d = try? JSONEncoder().encode(c) { UserDefaults.standard.set(d, forKey: defaultsKey) }
    }
}

/// 系统可用声音(按音质从高到低)
enum SystemVoices {
    static func list(for lang: Lang) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(lang == .zh ? "zh" : "en") }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    static func label(_ v: AVSpeechSynthesisVoice) -> String {
        let q: String
        switch v.quality {
        case .premium: q = " · 高级"
        case .enhanced: q = " · 增强"
        default: q = ""
        }
        return "\(v.name) (\(v.language))\(q)"
    }
}
