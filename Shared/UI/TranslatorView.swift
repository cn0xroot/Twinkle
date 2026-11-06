import SwiftUI

struct TranslatorView: View {
    @StateObject private var vm = TranslatorViewModel()
    @StateObject private var speech = SpeechInput()
    @State private var showSettings = false
    @ObservedObject private var ui = UISettings.shared
    @State private var pulse = false

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            Theme.softGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                languageBar.padding(.horizontal, 16).padding(.bottom, 8)
                content
                if let e = vm.error ?? speech.error {
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .padding(.horizontal, 16).padding(.bottom, 6)
                }
                inputBar.padding(.horizontal, 14).padding(.bottom, 14).padding(.top, 6)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .environment(\.locale, ui.locale)
        .sensoryFeedback(.impact, trigger: speech.isRecording)
        .onAppear {
            speech.onPartial = { vm.voicePartial($0) }
            speech.onFinal = { vm.voiceSegment($0) }
            if !Demo.enabled, !AppSettings.shared.config.isReady { showSettings = true }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.gradient)
            Text("Twinkle")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Spacer()
            iconButton(vm.autoSpeak ? "speaker.wave.2.fill" : "speaker.slash", active: vm.autoSpeak) { vm.autoSpeak.toggle() }
                .help("自动朗读译文")
            iconButton("trash") { withAnimation { vm.clearHistory() } }
                .opacity(vm.history.isEmpty ? 0.35 : 1).disabled(vm.history.isEmpty)
            iconButton("gearshape.fill") { showSettings = true }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
    }

    private func iconButton(_ name: String, active: Bool = false, _ action: @escaping () -> Void) -> some View {
        let fg: AnyShapeStyle = active ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
        let bg: AnyShapeStyle = active ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.regularMaterial)
        return Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 34, height: 34)
                .background(bg, in: Circle())
                .overlay(Circle().strokeBorder(.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Languages
    private var languageBar: some View {
        HStack(spacing: 8) {
            langMenu(vm.source?.label ?? L("自动检测"), icon: vm.source == nil ? "wand.and.stars" : "globe") {
                Button { vm.setSource(nil) } label: { check(L("自动检测"), vm.source == nil) }
                Divider()
                ForEach(Lang.allCases) { l in
                    Button { vm.setSource(l) } label: { check(l.label, vm.source == l) }
                }
            }
            Button { withAnimation(.snappy) { vm.swapLanguages() } } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.gradient, in: Circle())
            }
            .buttonStyle(.plain)
            langMenu(vm.target.label, icon: "character.bubble") {
                ForEach(Lang.allCases) { l in
                    Button { vm.setTarget(l) } label: { check(l.label, vm.target == l) }
                }
            }
        }
    }

    @ViewBuilder private func check(_ title: String, _ on: Bool) -> some View {
        if on { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private func langMenu<C: View>(_ title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        Menu { content() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(Theme.gradient)
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.06)))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    // MARK: Content
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if !vm.liveSource.isEmpty {
                    EntryCard(source: vm.liveSource, target: vm.liveTarget,
                              from: vm.liveLangs.from, to: vm.liveLangs.to, pending: true)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                ForEach(vm.history) {
                    EntryCard(source: $0.source, target: $0.target, from: $0.from, to: $0.to, pending: $0.pending)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if vm.history.isEmpty && vm.liveSource.isEmpty { emptyState }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .animation(.snappy, value: vm.history.count)
        }
        .defaultScrollAnchor(.top)
    }

    private var emptyState: some View {
        let samples = Self.samples(vm.source ?? vm.voiceSource)
        return VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.gradient).frame(width: 84, height: 84).opacity(0.15)
                Image(systemName: "sparkles").font(.system(size: 36, weight: .semibold)).foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 4) {
                Text("说点什么吧").font(.system(.title3, design: .rounded).weight(.bold))
                Text("输入文字,或点击下方麦克风实时互译").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(samples, id: \.self) { s in
                    Button { vm.input = s; vm.submit() } label: {
                        Text(s).font(.system(.subheadline, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 36)
    }

    // MARK: Input
    private var inputBar: some View {
        VStack(spacing: 8) {
            statusRow
            HStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 6) {
                    TextField(vm.inputPlaceholder, text: $vm.input, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(1...5)
                        .onSubmit { vm.submit() }
                        .padding(.vertical, 6)
                    let empty = vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button { vm.submit() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
                            .foregroundStyle(empty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.gradient))
                    }
                    .buttonStyle(.plain).disabled(empty)
                }
                .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.primary.opacity(0.08)))

                micButton
            }
        }
        .animation(.snappy, value: speech.isRecording)
    }

    /// 实时字幕开关 + 录音状态
    private var statusRow: some View {
        let on = vm.captionMode
        let fg: AnyShapeStyle = on ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
        let bg: AnyShapeStyle = on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.regularMaterial)
        return HStack(spacing: 10) {
            Button { vm.captionMode.toggle() } label: {
                Label("实时字幕", systemImage: on ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(fg)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(bg, in: Capsule())
                    .overlay(Capsule().strokeBorder(.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .disabled(speech.isRecording)
            .help("持续聆听,按停顿自动分句,逐句显示原文与译文")
            Spacer()
            if speech.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 8, height: 8).opacity(pulse ? 1 : 0.3)
                    Text(L(vm.captionMode ? "字幕中" : "正在聆听") + " · " + vm.voiceSource.label)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
    }

    private var micButton: some View {
        Button { speech.toggle(lang: vm.voiceSource, continuous: vm.captionMode) } label: {
            ZStack {
                if speech.isRecording {
                    Circle().stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .frame(width: 54, height: 54)
                        .scaleEffect(pulse ? 1.45 : 1).opacity(pulse ? 0 : 0.8)
                }
                Circle()
                    .fill(speech.isRecording ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Theme.gradient))
                    .frame(width: 54, height: 54)
                    .shadow(color: (speech.isRecording ? Color.red : Color.indigo).opacity(0.4), radius: 10, y: 4)
                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .disabled(speech.isStarting)
        .onChange(of: speech.isRecording) { _, rec in
            pulse = false
            if rec { withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true } }
        }
    }

    private static func samples(_ l: Lang) -> [String] {
        switch l {
        case .zh: return ["今天天气真好,我们出去走走吧。", "请问最近的地铁站怎么走?", "我想预订一张两人的桌子。"]
        case .en: return ["Where is the nearest subway station?", "Could you recommend a good restaurant?", "I'd like to book a table for two."]
        case .ja: return ["最寄りの駅はどこですか?", "おすすめのレストランを教えてください。", "二名で予約したいです。"]
        case .ko: return ["가장 가까운 지하철역이 어디예요?", "맛집 하나 추천해 주시겠어요?", "두 명 자리를 예약하고 싶어요."]
        case .fr: return ["Où est la station de métro la plus proche ?", "Pouvez-vous me recommander un bon restaurant ?", "Je voudrais réserver une table pour deux."]
        }
    }
}
