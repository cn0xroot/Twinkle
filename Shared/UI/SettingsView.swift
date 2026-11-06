import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var tts = TTSSettings.shared
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
        #if os(macOS)
        .frame(width: 540, height: 700)
        #endif
    }

    @ViewBuilder private var ttsSection: some View {
        Picker("朗读方案", selection: $tts.config.engine) {
            ForEach(TTSEngine.allCases) { Text($0.title).tag($0) }
        }
        if tts.config.engine == .system {
            voicePicker("中文声音", lang: .zh, selection: $tts.config.zhVoice)
            voicePicker("英文声音", lang: .en, selection: $tts.config.enVoice)
        }
        // 云端语音配置始终可见,方便先填好 Key 再切换方案
        Text("云端语音(OpenAI 兼容 TTS)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        SecureField("TTS API Key(留空沿用上方 OpenAI 兼容 Key)", text: $tts.config.apiKey)
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
            Text("语速 \(String(format: "%.1f", tts.config.speed))x")
            Slider(value: $tts.config.speed, in: 0.5...1.5, step: 0.1)
        }
        HStack {
            Button("试听中文") { Speaker.shared.speak("你好,很高兴认识你。", lang: .zh) }
            Button("Listen English") { Speaker.shared.speak("Hello, nice to meet you.", lang: .en) }
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
            modelError = error.localizedDescription + ",可手动输入模型名"
        }
    }
}
