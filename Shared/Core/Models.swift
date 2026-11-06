import Foundation

enum Lang: String, Codable {
    case zh, en

    var promptName: String { self == .zh ? "Simplified Chinese" : "English" }
    var speechLocale: String { self == .zh ? "zh-CN" : "en-US" }
    var other: Lang { self == .zh ? .en : .zh }
}

enum Direction: String, CaseIterable, Identifiable {
    case auto, zhToEn, enToZh
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "自动"
        case .zhToEn: return "中→英"
        case .enToZh: return "英→中"
        }
    }

    /// 文本翻译:自动模式按内容判断语言
    func resolve(for text: String) -> (from: Lang, to: Lang) {
        switch self {
        case .zhToEn: return (.zh, .en)
        case .enToZh: return (.en, .zh)
        case .auto:
            let from = LanguageDetector.detect(text)
            return (from, from.other)
        }
    }

    /// 语音输入必须在开口前确定语言,自动模式默认按中文处理
    var voiceSource: Lang { self == .enToZh ? .en : .zh }
}

enum LanguageDetector {
    static func detect(_ text: String) -> Lang {
        var cjk = 0, latin = 0
        for s in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(s.value) || (0x3400...0x4DBF).contains(s.value) { cjk += 1 }
            else if s.properties.isAlphabetic { latin += 1 }
        }
        return cjk >= latin && cjk > 0 ? .zh : (latin > 0 ? .en : .zh)
    }
}

struct Entry: Identifiable, Hashable {
    let id = UUID()
    let source: String
    let target: String
    let from: Lang
    let to: Lang
}
