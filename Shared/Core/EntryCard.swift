import SwiftUI

/// 双语对照卡片:原文在上(次要),译文在下(强调)
struct EntryCard: View {
    let source: String
    let target: String
    let from: Lang
    let to: Lang
    var pending = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                tag(from.label, filled: false)
                Text(source)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .selectable()
            }

            Rectangle().fill(Theme.gradient).frame(height: 1.5).opacity(0.35).clipShape(Capsule())

            VStack(alignment: .leading, spacing: 6) {
                tag(to.label, filled: true)
                if target.isEmpty && pending {
                    Image(systemName: "ellipsis").symbolEffect(.variableColor.iterative)
                        .foregroundStyle(Theme.gradient)
                } else {
                    Text(target)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .selectable()
                }
            }

            #if !os(watchOS)
            if !target.isEmpty && !pending {
                HStack(spacing: 6) {
                    Spacer()
                    action("speaker.wave.2.fill") { Speaker.shared.speak(target, lang: to) }
                    action(copied ? "checkmark" : "doc.on.doc") {
                        Clipboard.copy(target)
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { copied = false } }
                    }
                }
            }
            #else
            if !target.isEmpty && !pending {
                Button { Speaker.shared.speak(target, lang: to) } label: { Label("朗读", systemImage: "speaker.wave.2.fill") }
            }
            #endif
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(watchOS)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        #else
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(pending ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.primary.opacity(0.07)),
                          lineWidth: pending ? 1.5 : 1))
        .shadow(color: .indigo.opacity(pending ? 0.18 : 0.06), radius: pending ? 14 : 8, y: 3)
        #endif
    }

    private func tag(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(filled ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .background(filled ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary.opacity(0.6)), in: Capsule())
    }

    #if !os(watchOS)
    private func action(_ icon: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.quaternary.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
    }
    #endif
}

private extension View {
    @ViewBuilder func selectable() -> some View {
        #if os(watchOS)
        self
        #else
        self.textSelection(.enabled)
        #endif
    }
}
