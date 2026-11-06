import AVFoundation

/// 朗读译文:系统语音 / OpenAI 云端语音,云端失败自动退回系统语音
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?

    func speak(_ text: String, lang: Lang) {
        guard !text.isEmpty else { return }
        stop()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let cfg = TTSSettings.shared.config
        guard cfg.engine == .openai, !TTSSettings.shared.effectiveCloudKey.isEmpty else {
            speakSystem(text, lang: lang, cfg: cfg)
            return
        }
        let key = TTSSettings.shared.effectiveCloudKey
        task = Task { [weak self] in
            do {
                let data = try await Self.fetchCloudAudio(text, cfg: cfg, key: key)
                guard let self, !Task.isCancelled else { return }
                let p = try AVAudioPlayer(data: data)
                self.player = p
                p.play()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.speakSystem(text, lang: lang, cfg: cfg)   // 兜底
            }
        }
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        task?.cancel(); task = nil
        player?.stop(); player = nil
    }

    private func speakSystem(_ text: String, lang: Lang, cfg: TTSConfig) {
        let u = AVSpeechUtterance(string: text)
        let id = cfg.voices[lang.rawValue] ?? ""
        u.voice = (id.isEmpty ? nil : AVSpeechSynthesisVoice(identifier: id)) ?? AVSpeechSynthesisVoice(language: lang.speechLocale)
        u.rate = min(max(AVSpeechUtteranceDefaultSpeechRate * Float(cfg.speed), AVSpeechUtteranceMinimumSpeechRate),
                     AVSpeechUtteranceMaximumSpeechRate)
        synth.speak(u)
    }

    private nonisolated static func fetchCloudAudio(_ text: String, cfg: TTSConfig, key: String) async throws -> Data {
        let base = cfg.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/audio/speech") else { throw TranslationError(message: L("TTS Base URL 无效")) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": cfg.model, "voice": cfg.voice, "input": text,
                                   "response_format": "mp3", "speed": min(max(cfg.speed, 0.25), 4)]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw TranslationError(message: L("云端语音失败"))
        }
        return data
    }
}
