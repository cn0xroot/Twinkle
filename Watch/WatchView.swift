import SwiftUI

struct WatchView: View {
    @StateObject private var vm = TranslatorViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ui = UISettings.shared

    var body: some View {
        NavigationStack {
            List {
                Picker("源语言", selection: Binding(get: { vm.source }, set: { vm.setSource($0) })) {
                    Text("自动").tag(Lang?.none)
                    ForEach(Lang.allCases) { Text($0.label).tag(Lang?.some($0)) }
                }
                Picker("目标语言", selection: Binding(get: { vm.target }, set: { vm.setTarget($0) })) {
                    ForEach(Lang.allCases) { Text($0.label).tag($0) }
                }
                // 点击输入框即可使用系统听写(中/英)、手写或键盘
                TextField("说话或输入", text: $vm.input)
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
        .environment(\.locale, ui.locale)
    }
}
