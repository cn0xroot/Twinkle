import SwiftUI

@main
struct TwinkleApp: App {
    init() { WatchSync.shared.start() }
    var body: some Scene {
        WindowGroup { TranslatorView() }
    }
}
