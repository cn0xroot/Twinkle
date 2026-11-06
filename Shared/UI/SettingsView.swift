import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var tts = TTSSettings.shared
    @ObservedObject private var ui = UISettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var models: [String] = []
    @State private var loading = false
    @State private var modelError: String?

    /// 网络请求依赖项变化时重新拉取
    private var fetchKey: String {
        let c = settings.config
        return "\(c.provider.rawValue)|\(c.baseURL)|\(c.apiKey)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("界面语言", selection: $ui.lang) {
                        ForEach(UILang.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Label("通用", systemImage: "globe")
                }
                Section {
                    Picker("接口类型", selection: Binding(
                        get: { settings.config.provider },
                        set: { p in
                            settings.config.provider = p
                            settings.config.baseURL = p.defaultBaseURL
                            settings.config.model = p.defaultModel
                        })) {
                        ForEach(Provider.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("Base URL", text: $settings.config.baseURL)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: $settings.config.apiKey)
                    modelRow
                } header: {
                    Label("大模型", systemImage: "sparkles")
                }
                Section { ttsSection } header: {
                    Label("朗读", systemImage: "speaker.wave.2.fill")
                }
                Section {
                    Text("API Key 保存在系统钥匙串中。iPhone 上的配置会自动同步到 Apple Watch。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .task(id: fetchKey) { await loadModels() }
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .environment(\.locale, ui.locale)
        #if os(macOS)
        .frame(width: 540, height: 780)
        #endif
    }

    @ViewBuilder private var ttsSection: some View {
        Picker("朗读方案", selection: $tts.config.engine) {
            ForEach(TTSEngine.allCases) { Text($0.title).tag($0) }
        }
        if tts.config.engine == .system {
            ForEach(Lang.allCases) { l in
                voicePicker(L("%@ 声音", l.label), lang: l, selection: Binding(
                    get: { tts.config.voices[l.rawValue] ?? "" },
                    set: { tts.config.voices[l.rawValue] = $0.isEmpty ? nil : $0 }))
            }
        }
        // 云端语音配置始终可见,方便先填好 Key 再切换方案
        Text("云端语音(OpenAI 兼容 TTS)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        SecureField("TTS API Key", text: $tts.config.apiKey, prompt: Text("留空则沿用上方 Key"))
        TextField("TTS Base URL", text: $tts.config.baseURL).autocorrectionDisabled()
        Picker("模型", selection: $tts.config.model) {
            ForEach(TTSConfig.cloudModels, id: \.self) { Text($0).tag($0) }
        }
        Picker("音色", selection: $tts.config.voice) {
            ForEach(TTSConfig.cloudVoices, id: \.self) { Text($0.capitalized).tag($0) }
        }
        if tts.config.engine == .openai && tts.effectiveCloudKey.isEmpty {
            Text("未配置 Key,将退回系统语音").font(.footnote).foregroundStyle(.orange)
        }
        HStack {
            Text(L("语速 %@x", String(format: "%.1f", tts.config.speed)))
            Slider(value: $tts.config.speed, in: 0.5...1.5, step: 0.1)
        }
        HStack {
            Menu("试听") {
                ForEach(Lang.allCases) { l in
                    Button(l.label) { Speaker.shared.speak(Self.sample(l), lang: l) }
                }
            }
        }
    }

    private static func sample(_ l: Lang) -> String {
        switch l {
        case .zh: return "你好,很高兴认识你。"
        case .en: return "Hello, nice to meet you."
        case .ja: return "こんにちは、はじめまして。"
        case .ko: return "안녕하세요, 만나서 반갑습니다."
        case .fr: return "Bonjour, ravi de vous rencontrer."
        }
    }

    private func voicePicker(_ title: String, lang: Lang, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("系统默认").tag("")
            ForEach(SystemVoices.list(for: lang), id: \.identifier) { Text(SystemVoices.label($0)).tag($0.identifier) }
        }
    }

    @ViewBuilder private var modelRow: some View {
        HStack {
            if models.isEmpty {
                // 未获取到列表时退回手动输入
                TextField("模型", text: $settings.config.model).autocorrectionDisabled()
            } else {
                Picker("模型", selection: $settings.config.model) {
                    // 当前值不在列表中时仍保留,避免选中项丢失
                    if !models.contains(settings.config.model) {
                        Text(settings.config.model).tag(settings.config.model)
                    }
                    ForEach(models, id: \.self) { Text($0).tag($0) }
                }
            }
            if loading { ProgressView().controlSize(.small) }
            else {
                Button { Task { await loadModels(debounce: false) } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(!settings.config.isReady)
            }
        }
        if let modelError {
            Text(modelError).font(.footnote).foregroundStyle(.red)
        }
    }

    private func loadModels(debounce: Bool = true) async {
        if Demo.enabled { models = Demo.models; return }
        guard settings.config.isReady else { models = []; modelError = nil; return }
        if debounce { try? await Task.sleep(nanoseconds: 600_000_000) }   // 等输入停下
        if Task.isCancelled { return }
        loading = true; modelError = nil
        defer { loading = false }
        do {
            let list = try await TranslationClient(config: settings.config).listModels()
            if Task.isCancelled { return }
            models = list
            // 当前模型不在列表里时,自动选第一个可用模型
            if !list.isEmpty, !list.contains(settings.config.model) { settings.config.model = list[0] }
        } catch {
            if Task.isCancelled || error is CancellationError { return }
            models = []
            modelError = error.localizedDescription + " · " + L("可手动输入模型名")
        }
    }
}
