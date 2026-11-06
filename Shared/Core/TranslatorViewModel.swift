import Foundation
import SwiftUI

@MainActor
final class TranslatorViewModel: ObservableObject {
    @Published var input = ""
    /// nil = 自动检测源语言
    @Published private(set) var source: Lang?
    @Published private(set) var target: Lang = .en
    @Published var history: [Entry] = []
    @Published var error: String?
    @Published var autoSpeak = false
    /// 实时字幕:持续聆听,按停顿自动分句,逐句双语显示
    @Published var captionMode = false

    // 语音识别中的"正在说"那一句(预览,尚未定稿)
    @Published var liveSource = ""
    @Published var liveTarget = ""
    @Published var liveLangs: (from: Lang, to: Lang) = (.zh, .en)

    private var previewTask: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    /// 每个定稿的句子独立翻译,互不取消(字幕模式下连续出句)
    private var commitTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        if Demo.enabled {
            history = Demo.history
            captionMode = true
            liveSource = Demo.live.source; liveTarget = Demo.live.target; liveLangs = (Demo.live.from, Demo.live.to)
            return
        }
        let d = UserDefaults.standard
        if let t = d.string(forKey: "lang.target").flatMap(Lang.init(rawValue:)) { target = t }
        if let s = d.string(forKey: "lang.source").flatMap(Lang.init(rawValue:)), s != target { source = s }
    }

    // MARK: 语言选择(源语言与目标语言始终不同)
    func setSource(_ l: Lang?) {
        if let l, l == target { target = source ?? l.partner }
        source = l
        saveLanguages()
    }

    func setTarget(_ l: Lang) {
        if l == source { source = target }
        target = l
        saveLanguages()
    }

    func swapLanguages() {
        let t = target
        if let s = source { source = t; target = s } else { source = t; target = t.partner }
        saveLanguages()
    }

    private func saveLanguages() {
        guard !Demo.enabled else { return }
        UserDefaults.standard.set(source?.rawValue, forKey: "lang.source")
        UserDefaults.standard.set(target.rawValue, forKey: "lang.target")
    }

    /// 文本翻译:自动模式按内容判断源语言
    func resolve(for text: String) -> (from: Lang, to: Lang) {
        if let s = source { return (s, target) }
        let d = LanguageDetector.detect(text)
        return (d, d == target ? target.partner : target)
    }

    /// 语音输入必须在开口前确定语言;自动模式下:目标是中文则按英文识别,否则按中文识别
    var voiceSource: Lang { source ?? (target == .zh ? .en : .zh) }
    func voiceLangs() -> (from: Lang, to: Lang) { (voiceSource, target) }
    var inputPlaceholder: String { source.map { L("输入%@…", $0.label) } ?? L("输入要翻译的文字…") }

    // MARK: 文本
    func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        commit(text, langs: resolve(for: text), restoreInputOnFailure: true)
    }

    // MARK: 语音
    /// 实时中间结果:显示原文,防抖后流式预览译文
    func voicePartial(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        liveSource = t
        liveLangs = voiceLangs()
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, let self else { return }
            self.preview(t, langs: self.voiceLangs())
        }
    }

    /// 一句话定稿(停顿或停止录音):进入历史并独立翻译
    func voiceSegment(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        clearLive()
        guard !t.isEmpty else { return }
        commit(t, langs: voiceLangs())
    }

    func clearHistory() {
        commitTasks.values.forEach { $0.cancel() }
        commitTasks.removeAll()
        clearLive()
        history.removeAll()
    }

    // MARK: 内部
    private func clearLive() {
        debounce?.cancel(); previewTask?.cancel()
        liveSource = ""; liveTarget = ""
    }

    private func preview(_ text: String, langs: (from: Lang, to: Lang)) {
        previewTask?.cancel()
        let client = TranslationClient(config: AppSettings.shared.config)
        previewTask = Task { [weak self] in
            var result = ""
            do {
                for try await piece in client.stream(text, from: langs.from, to: langs.to) {
                    guard let self, !Task.isCancelled else { return }
                    result += piece
                    self.liveTarget = result      // 首个片段到达时才替换旧预览,避免闪烁
                }
            } catch is CancellationError {
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
    }

    private func commit(_ text: String, langs: (from: Lang, to: Lang), restoreInputOnFailure: Bool = false) {
        error = nil
        let entry = Entry(source: text, target: "", from: langs.from, to: langs.to, pending: true)
        let id = entry.id
        history.insert(entry, at: 0)
        let client = TranslationClient(config: AppSettings.shared.config)
        commitTasks[id] = Task { [weak self] in
            var result = ""
            do {
                for try await piece in client.stream(text, from: langs.from, to: langs.to) {
                    guard let self, !Task.isCancelled else { return }
                    result += piece
                    self.update(id) { $0.target = result }
                }
                guard let self, !Task.isCancelled else { return }
                let final = result.trimmingCharacters(in: .whitespacesAndNewlines)
                self.update(id) { $0.target = final; $0.pending = false }
                self.commitTasks[id] = nil
                if self.autoSpeak && !self.captionMode { Speaker.shared.speak(final, lang: langs.to) }
            } catch is CancellationError {
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.history.removeAll { $0.id == id }
                self.commitTasks[id] = nil
                if restoreInputOnFailure && self.input.isEmpty { self.input = text }
            }
        }
    }

    private func update(_ id: UUID, _ change: (inout Entry) -> Void) {
        if let i = history.firstIndex(where: { $0.id == id }) { change(&history[i]) }
    }
}
