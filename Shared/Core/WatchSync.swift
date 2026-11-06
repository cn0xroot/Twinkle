#if os(iOS) || os(watchOS)
import Foundation
import WatchConnectivity

/// iPhone → Watch 同步 LLM 配置(手表上不方便输入 API Key)
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()
    private let key = "llm.config"
    private let ttsKey = "tts.config"

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        #if os(iOS)
        Task { @MainActor in
            AppSettings.shared.onChange = { [weak self] _ in self?.push() }
            TTSSettings.shared.onChange = { [weak self] _ in self?.push() }
        }
        #endif
    }

    #if os(iOS)
    @MainActor func push() {
        guard WCSession.default.activationState == .activated,
              let d = try? JSONEncoder().encode(AppSettings.shared.config),
              let t = try? JSONEncoder().encode(TTSSettings.shared.config) else { return }
        try? WCSession.default.updateApplicationContext([key: d, ttsKey: t])
    }
    #endif

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        #if os(iOS)
        Task { @MainActor in self.push() }
        #else
        receive(session.receivedApplicationContext)
        #endif
    }

    func session(_ session: WCSession, didReceiveApplicationContext ctx: [String: Any]) { receive(ctx) }

    private func receive(_ ctx: [String: Any]) {
        if let d = ctx[key] as? Data, let c = try? JSONDecoder().decode(LLMConfig.self, from: d) {
            Task { @MainActor in AppSettings.shared.apply(remote: c) }
        }
        if let d = ctx[ttsKey] as? Data, let c = try? JSONDecoder().decode(TTSConfig.self, from: d) {
            Task { @MainActor in TTSSettings.shared.apply(remote: c) }
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
#endif
