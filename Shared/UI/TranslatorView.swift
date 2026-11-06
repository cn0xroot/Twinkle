import SwiftUI

struct TranslatorView: View {
    @StateObject private var vm = TranslatorViewModel()
    @StateObject private var speech = SpeechInput()
    @State private var showSettings = false
    @State private var pulse = false
    @Namespace private var dirNS

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            Theme.softGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                directionPicker.padding(.horizontal, 16).padding(.bottom, 8)
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
        .sensoryFeedback(.impact, trigger: speech.isRecording)
        .onAppear {
            speech.onPartial = { vm.voicePartial($0) }
            speech.onFinal = { vm.voiceFinal($0) }
            if !AppSettings.shared.config.isReady { showSettings = true }
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

    // MARK: Direction
    private var directionPicker: some View {
        HStack(spacing: 4) {
            ForEach(Direction.allCases) { d in
                Text(d.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .foregroundStyle(vm.direction == d ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .background {
                        if vm.direction == d {
                            Capsule().fill(Theme.gradient).matchedGeometryEffect(id: "dir", in: dirNS)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.snappy) { vm.direction = d } }
            }
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.06)))
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
                    EntryCard(source: $0.source, target: $0.target, from: $0.from, to: $0.to)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if vm.history.isEmpty && vm.liveSource.isEmpty { emptyState }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .animation(.snappy, value: vm.history.count)
        }
    }

    private var emptyState: some View {
        let samples = vm.direction == .enToZh
            ? ["Where is the nearest subway station?", "Could you recommend a good restaurant?", "I'd like to book a table for two."]
            : ["今天天气真好,我们出去走走吧。", "请问最近的地铁站怎么走?", "我想预订一张两人的桌子。"]
        return VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.gradient).frame(width: 84, height: 84).opacity(0.15)
                Image(systemName: "sparkles").font(.system(size: 36, weight: .semibold)).foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 4) {
                Text("说点什么吧").font(.system(.title3, design: .rounded).weight(.bold))
                Text("输入文字,或按住下方麦克风实时互译").font(.subheadline).foregroundStyle(.secondary)
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
            if speech.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 8, height: 8).opacity(pulse ? 1 : 0.3)
                    Text("正在聆听 · \(vm.direction.voiceSource.label)")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
            HStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 6) {
                    TextField(vm.direction == .enToZh ? "Type English…" : "输入中文…", text: $vm.input, axis: .vertical)
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

    private var micButton: some View {
        Button { speech.toggle(lang: vm.direction.voiceSource) } label: {
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
        .onChange(of: speech.isRecording) { _, rec in
            pulse = false
            if rec { withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true } }
        }
    }
}
