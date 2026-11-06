import Foundation
import NaturalLanguage

enum Lang: String, Codable, CaseIterable, Identifiable {
    case zh, en, ja, ko, fr

    var id: String { rawValue }
    /// 语言代码,用于匹配系统语音
    var code: String { rawValue }

    var promptName: String {
        switch self {
        case .zh: return "Simplified Chinese"
        case .en: return "English"
        case .ja: return "Japanese"
        case .ko: return "Korean"
        case .fr: return "French"
        }
    }

    var speechLocale: String {
        switch self {
        case .zh: return "zh-CN"
        case .en: return "en-US"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        case .fr: return "fr-FR"
        }
    }

    /// 以该语言自身书写的名称
    var label: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        }
    }

    /// 源语言与目标语言相同时的替代目标:中文 ⇄ 英文,其余默认中文
    var partner: Lang { self == .zh ? .en : .zh }
}

enum LanguageDetector {
    static func detect(_ text: String) -> Lang {
        var kana = 0, hangul = 0, han = 0, latin = 0
        for s in text.unicodeScalars {
            switch s.value {
            case 0x3040...0x30FF: kana += 1
            case 0xAC00...0xD7AF, 0x1100...0x11FF: hangul += 1
            case 0x4E00...0x9FFF, 0x3400...0x4DBF: han += 1
            default: if s.properties.isAlphabetic { latin += 1 }
            }
        }
        if kana > 0 { return .ja }
        if hangul > 0 { return .ko }
        if han > 0 && han >= latin { return .zh }
        if latin > 0 {
            let r = NLLanguageRecognizer()
            r.languageConstraints = [.english, .french]
            r.processString(text)
            return r.dominantLanguage == .french ? .fr : .en
        }
        return .zh
    }
}

struct Entry: Identifiable, Hashable {
    let id = UUID()
    let source: String
    var target: String
    let from: Lang
    let to: Lang
    var pending = false
}
