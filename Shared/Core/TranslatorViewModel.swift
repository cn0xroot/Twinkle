import Foundation
import SwiftUI

@MainActor
final class TranslatorViewModel: ObservableObject {
    @Published var input = ""
    @Published var direction: Direction = .auto
    @Published var liveSource = ""
    @Published var liveTarget = ""
    @Published var history: [Entry] = []
    @Published var isBusy = false
    @Published var error: String?
    @Published var autoSpeak = false
    @Published var liveLangs: (from: Lang, to: Lang) = (.zh, .en)

    private var task: Task<Void, Never>?
    private var debounce: Task<Void, Never>?

    /// 文本翻译:提交后进入历史
    func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        run(text, langs: direction.resolve(for: text), commit: true)
    }

    /// 语音实时中间结果:防抖后流式翻译,不入历史
    func voicePartial(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        liveSource = t
        liveLangs = voiceLangs()
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, let self else { return }
            self.run(t, langs: self.voiceLangs(), commit: false)
        }
    }

    /// 语音结束:最终文本翻译并入历史
    func voiceFinal(_ text: String) {
        debounce?.cancel()
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { cancelLive(); return }
        run(t, langs: voiceLangs(), commit: true)
    }

    func voiceLangs() -> (from: Lang, to: Lang) {
        let s = direction.voiceSource
        return (s, s.other)
    }

    func clearHistory() { history.removeAll(); cancelLive() }

    private func cancelLive() {
        task?.cancel(); isBusy = false; liveSource = ""; liveTarget = ""
    }

    private func run(_ text: String, langs: (from: Lang, to: Lang), commit: Bool) {
        task?.cancel()
        error = nil
        liveSource = text
        liveTarget = ""
        liveLangs = langs
        isBusy = true
        let client = TranslationClient(config: AppSettings.shared.config)
        task = Task { [weak self] in
            var result = ""
            do {
                for try await piece in client.stream(text, from: langs.from, to: langs.to) {
                    guard let self, !Task.isCancelled else { return }
                    result += piece
                    self.liveTarget = result
                }
                guard let self, !Task.isCancelled else { return }
                self.isBusy = false
                if commit {
                    let final = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.history.insert(Entry(source: text, target: final, from: langs.from, to: langs.to), at: 0)
                    self.liveSource = ""; self.liveTarget = ""
                    if self.autoSpeak { Speaker.shared.speak(final, lang: langs.to) }
                }
            } catch is CancellationError {
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isBusy = false
                self.error = error.localizedDescription
            }
        }
    }
}
