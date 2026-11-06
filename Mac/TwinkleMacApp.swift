import SwiftUI

@main
struct TwinkleMacApp: App {
    var body: some Scene {
        WindowGroup {
            if Demo.settingsOnly { SettingsView() } else { TranslatorView() }
        }
        .defaultSize(width: 520, height: 800)
    }
}
