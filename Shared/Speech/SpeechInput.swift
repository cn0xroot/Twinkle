import Foundation
import AVFoundation
import Speech

/// 实时语音识别(Apple Speech),中文 zh-CN / 英文 en-US
final class SpeechInput: ObservableObject {
    @Published var isRecording = false
    @Published var error: String?

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var finished = false

    func toggle(lang: Lang) {
        if isRecording { stop() } else { Task { await start(lang: lang) } }
    }

    @MainActor
    func start(lang: Lang) async {
        guard !isRecording else { return }
        error = nil
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { error = "未授权语音识别,请在系统设置中开启"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: lang.speechLocale)),
              recognizer.isAvailable else { error = "当前语言的语音识别不可用"; return }

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            Speaker.shared.stop()
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req
            latest = ""
            finished = false
            try Self.installTap(on: engine, into: req)
            engine.prepare()
            try engine.start()
            task = recognizer.recognitionTask(with: req) { [weak self] result, err in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let result {
                        self.latest = result.bestTranscription.formattedString
                        if result.isFinal { self.finish() } else { self.onPartial?(self.latest) }
                    }
                    if err != nil, self.isRecording || !self.finished { self.finish() }
                }
            }
            isRecording = true
        } catch {
            self.error = error.localizedDescription
            teardown()
        }
    }

    func stop() {
        guard isRecording else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()   // 触发 isFinal;若未触发,0.8s 后兜底
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let text = latest
        teardown()
        onFinal?(text)
    }

    private func teardown() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        task?.cancel(); task = nil; request = nil
        isRecording = false
    }

    // 在非隔离上下文安装 tap,避免音频线程上的 actor 隔离断言
    private static func installTap(on engine: AVAudioEngine, into req: SFSpeechAudioBufferRecognitionRequest) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
    }
}
