import SwiftUI

/// 界面语言(与"翻译语言"无关)
enum UILang: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case en

    var id: String { rawValue }
    /// 各选项始终以自身语言显示,方便找到
    var title: String {
        switch self {
        case .system: return "跟随系统 / System"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

enum UIStore { static var raw = "system" }

/// 按当前界面语言取文案。键为简体中文原文,缺失时回退为键本身。
func L(_ key: String) -> String {
    if UIStore.raw != "system",
       let path = Bundle.main.path(forResource: UIStore.raw, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}

@MainActor
final class UISettings: ObservableObject {
    static let shared = UISettings()
    private let key = "ui.lang"

    @Published var lang: UILang {
        didSet {
            UIStore.raw = lang.rawValue
            if !Demo.enabled { UserDefaults.standard.set(lang.rawValue, forKey: key) }
        }
    }

    var locale: Locale {
        lang == .system ? .autoupdatingCurrent : Locale(identifier: lang.rawValue)
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "ui.lang").flatMap(UILang.init(rawValue:))
        let initial = Demo.uiLang.flatMap(UILang.init(rawValue:)) ?? saved ?? .system
        lang = initial
        UIStore.raw = initial.rawValue
    }
}
