import Foundation
import AVFoundation
import Speech

/// 实时语音识别(Apple Speech)。
/// - 普通模式:点击开始,再点击停止,整段作为一句。
/// - 字幕模式(continuous):持续聆听,停顿约 1.3 秒自动断句并立即开始下一句,音频不中断。
final class SpeechInput: ObservableObject {
    @Published var isRecording = false
    /// 正在启动(等待授权/初始化):期间忽略重复点击,避免同时启动两次录音
    @Published var isStarting = false
    @Published var error: String?

    /// 实时中间结果(整句累计文本)
    var onPartial: ((String) -> Void)?
    /// 一句话定稿
    var onFinal: ((String) -> Void)?

    private static let silenceGap: TimeInterval = 1.3

    private let engine = AVAudioEngine()
    private let box = RequestBox()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var continuous = false
    private var stopping = false
    private var generation = 0
    private var failures = 0
    private var silenceWork: DispatchWorkItem?

    func toggle(lang: Lang, continuous: Bool) {
        if isRecording {
            stop()
        } else if !isStarting {
            isStarting = true            // 必须在异步任务之前同步置位,否则快速连点会启动两次
            Task { await start(lang: lang, continuous: continuous) }
        }
    }

    @MainActor
    func start(lang: Lang, continuous: Bool) async {
        defer { isStarting = false }
        guard !isRecording else { return }
        error = nil; stopping = false; failures = 0; latest = ""
        self.continuous = continuous
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { error = L("未授权语音识别,请在系统设置中开启"); return }
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: lang.speechLocale)), rec.isAvailable else {
            error = L("当前语言的语音识别不可用"); return
        }
        recognizer = rec
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            Speaker.shared.stop()
            try Self.installTap(on: engine, box: box)
            engine.prepare()
            try engine.start()
            isRecording = true
            startTask()
        } catch {
            self.error = error.localizedDescription
            teardown()
        }
    }

    func stop() {
        guard isRecording, !stopping else { return }
        stopping = true
        silenceWork?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        box.finishCurrent()   // endAudio → 触发 isFinal;若未触发,0.8s 后兜底
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            if self?.isRecording == true { self?.segmentEnded() }
        }
    }

    // MARK: 识别任务(字幕模式下会连续创建新任务,麦克风音频不中断)
    private func startTask() {
        guard let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        box.set(req)
        latest = ""
        generation += 1
        let gen = generation
        task = recognizer.recognitionTask(with: req) { [weak self] result, err in
            DispatchQueue.main.async {
                guard let self, gen == self.generation, self.isRecording else { return }
                if let result {
                    self.failures = 0
                    self.latest = result.bestTranscription.formattedString
                    if result.isFinal { self.segmentEnded() }
                    else { self.onPartial?(self.latest); self.armSilenceTimer() }
                } else if err != nil {
                    self.failures += 1
                    self.segmentEnded(failed: true)
                }
            }
        }
    }

    private func armSilenceTimer() {
        guard continuous else { return }
        silenceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isRecording, !self.stopping, self.continuous,
                  !self.latest.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            self.segmentEnded()
        }
        silenceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.silenceGap, execute: work)
    }

    /// 一句话结束:交付文本,然后继续下一句或收尾
    private func segmentEnded(failed: Bool = false) {
        silenceWork?.cancel()
        generation += 1                       // 让旧任务的迟到回调失效
        task?.cancel(); task = nil
        box.finishCurrent()
        let text = latest
        latest = ""
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onFinal?(text) }

        guard continuous, !stopping else { teardown(); return }
        if failed && failures >= 4 { error = L("语音识别中断,请重试"); teardown(); return }
        if failed && text.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.isRecording, !self.stopping else { return }
                self.startTask()
            }
        } else {
            startTask()
        }
    }

    private func teardown() {
        silenceWork?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel(); task = nil
        box.set(nil)
        isRecording = false
        stopping = false
    }

    // 在非隔离上下文安装 tap,避免音频线程上的 actor 隔离断言
    private static func installTap(on engine: AVAudioEngine, box: RequestBox) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // 没有可用麦克风时采样率为 0,安装 tap 会直接抛异常导致崩溃
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "Twinkle", code: 1, userInfo: [NSLocalizedDescriptionKey: L("未检测到可用的麦克风")])
        }
        input.removeTap(onBus: 0)        // 同一通道重复安装 tap 会崩溃,先清理
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in box.append(buffer) }
    }
}

/// 音频线程与主线程共享当前识别请求
private final class RequestBox {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ r: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); request = r; lock.unlock()
    }
    func append(_ b: AVAudioPCMBuffer) {
        lock.lock(); let r = request; lock.unlock()
        r?.append(b)
    }
    func finishCurrent() {
        lock.lock(); let r = request; lock.unlock()
        r?.endAudio()
    }
}
