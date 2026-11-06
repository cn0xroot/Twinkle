import SwiftUI

struct WatchView: View {
    @StateObject private var vm = TranslatorViewModel()
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Picker("方向", selection: $vm.direction) {
                    ForEach(Direction.allCases) { Text($0.title).tag($0) }
                }
                // 点击输入框即可使用系统听写(中/英)、手写或键盘
                TextField(vm.direction == .enToZh ? "Speak or type" : "说话或输入", text: $vm.input)
                    .submitLabel(.send)
                    .onSubmit { vm.submit() }

                if !settings.config.isReady {
                    Text("请先在 iPhone 上的 Twinkle 中配置 API Key").font(.footnote).foregroundStyle(.orange)
                }
                if let e = vm.error { Text(e).font(.footnote).foregroundStyle(.red) }

                if !vm.liveSource.isEmpty {
                    EntryCard(source: vm.liveSource, target: vm.liveTarget,
                              from: vm.liveLangs.from, to: vm.liveLangs.to, pending: true)
                        .listRowBackground(Color.clear)
                }
                ForEach(vm.history) {
                    EntryCard(source: $0.source, target: $0.target, from: $0.from, to: $0.to).listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Twinkle")
        }
    }
}
