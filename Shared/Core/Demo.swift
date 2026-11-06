import Foundation

/// 仅 Debug 构建可用的演示模式(用于生成 README 截图):
/// `-demo` 填充示例数据且不读写钥匙串/偏好设置;`-demoSettings` 直接显示设置页。
enum Demo {
    #if DEBUG
    static let enabled = CommandLine.arguments.contains("-demo") || CommandLine.arguments.contains("-demoSettings")
    static var uiLang: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "-uiLang"), i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }
    static let settingsOnly = CommandLine.arguments.contains("-demoSettings")
    #else
    static let enabled = false
    static let settingsOnly = false
    static let uiLang: String? = nil
    #endif

    static let models = ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5", "claude-fable-5-1"]

    /// 字幕模式下"正在说"的那一句
    static let live = (source: "Pouvez-vous me dire où se trouve la gare ?",
                       target: "你能告诉我火车站在哪里吗?", from: Lang.fr, to: Lang.zh)

    static let history: [Entry] = [
        Entry(source: "请问最近的地铁站怎么走?",
              target: "Excuse me, how do I get to the nearest subway station?", from: .zh, to: .en),
        Entry(source: "Je voudrais réserver une table pour deux.",
              target: "I'd like to book a table for two.", from: .fr, to: .en),
    ]
}
