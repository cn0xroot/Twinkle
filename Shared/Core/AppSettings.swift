import Foundation
import SwiftUI

enum Provider: String, Codable, CaseIterable, Identifiable {
    case anthropic, openai
    var id: String { rawValue }
    var title: String { self == .anthropic ? "Anthropic (Claude)" : "OpenAI 兼容" }
    var defaultBaseURL: String { self == .anthropic ? "https://api.anthropic.com" : "https://api.openai.com/v1" }
    var defaultModel: String { self == .anthropic ? "claude-haiku-5-5" : "gpt-4o-mini" }
}

struct LLMConfig: Codable, Equatable {
    var provider: Provider = .anthropic
    var baseURL: String = Provider.anthropic.defaultBaseURL
    var model: String = Provider.anthropic.defaultModel
    var apiKey: String = ""
    var isReady: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaultsKey = "llm.config"

    /// 配置变化时回调(iPhone 用来同步到手表)
    var onChange: ((LLMConfig) -> Void)?

    @Published var config: LLMConfig {
        didSet { persist(); onChange?(config) }
    }

    private init() {
        var c = LLMConfig()
        if let d = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(LLMConfig.self, from: d) { c = saved }
        c.apiKey = Keychain.get("default")
        config = c
    }

    /// 接收来自 iPhone 的配置,不再回传
    func apply(remote: LLMConfig) {
        let cb = onChange
        onChange = nil
        config = remote
        onChange = cb
    }

    private func persist() {
        var c = config
        Keychain.set(c.apiKey, for: "default")
        c.apiKey = ""
        if let d = try? JSONEncoder().encode(c) { UserDefaults.standard.set(d, forKey: defaultsKey) }
    }
}
