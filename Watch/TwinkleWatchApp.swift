import SwiftUI

@main
struct TwinkleWatchApp: App {
    init() { WatchSync.shared.start() }
    var body: some Scene {
        WindowGroup { WatchView() }
    }
}
