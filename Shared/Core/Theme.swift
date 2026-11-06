import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Twinkle 视觉主题:靛蓝 → 紫 → 粉的星光渐变
enum Theme {
    static let gradient = LinearGradient(colors: [.indigo, .purple, .pink.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let softGradient = LinearGradient(colors: [.indigo.opacity(0.14), .purple.opacity(0.07), .clear],
                                             startPoint: .top, endPoint: .center)
}

enum Clipboard {
    static func copy(_ s: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = s
        #endif
    }
}
