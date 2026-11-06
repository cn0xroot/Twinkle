import Foundation

/// 仅 Debug 构建可用的演示模式(用于生成 README 截图):
/// `-demo` 填充示例数据且不读写钥匙串/偏好设置;`-demoSettings` 直接显示设置页。
enum Demo {
    #if DEBUG
    static let enabled = CommandLine.arguments.contains("-demo") || CommandLine.arguments.contains("-demoSettings")
    static let settingsOnly = CommandLine.arguments.contains("-demoSettings")
    #else
    static let enabled = false
    static let settingsOnly = false
    #endif

    static let models = ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5", "claude-fable-5-1"]

    static let history: [Entry] = [
        Entry(source: "请问最近的地铁站怎么走?",
              target: "Excuse me, how do I get to the nearest subway station?", from: .zh, to: .en),
        Entry(source: "Where can I find a good coffee shop around here?",
              target: "这附近哪里有不错的咖啡店?", from: .en, to: .zh),
        Entry(source: "今天天气真好,我们出去走走吧。",
              target: "The weather is lovely today — let's go for a walk.", from: .zh, to: .en),
    ]
}
