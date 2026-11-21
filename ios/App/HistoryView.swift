import SwiftUI
import UIKit

struct HistoryView: View {
    @ObservedObject private var store = RecordStore.shared
    @State private var toast: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if store.items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.items) { item in
                            row(item)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture { copy(item) }
                        }
                        .onDelete { idx in
                            for i in idx { store.delete(store.items[i].id) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                if let t = toast {
                    VStack {
                        Spacer()
                        Text(t)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.black.opacity(0.82)))
                            .padding(.bottom, 24)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("听写记录")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.items.isEmpty {
                        Menu {
                            Button("刷新") { store.reload() }
                            Button("清空全部", role: .destructive) { store.clearAll() }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear { store.reload() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 46))
                .foregroundColor(Theme.sub.opacity(0.6))
            Text("还没有记录")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("切换到「语音听写」键盘，\n按住空格键说一句话试试。")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.sub)
                .lineSpacing(3)
        }
        .padding(.bottom, 60)
    }

    private func row(_ item: Dictation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.text)
                .font(.system(size: 16))
                .foregroundColor(Theme.text)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(Fmt.relative(item.createdAt))
                if item.seconds > 0 {
                    Text("·")
                    Text(Fmt.duration(item.seconds))
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
            }
            .font(.system(size: 12))
            .foregroundColor(Theme.sub)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.card)
        )
        .padding(.vertical, 4)
    }

    private func copy(_ item: Dictation) {
        UIPasteboard.general.string = item.text
        withAnimation { toast = "已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { toast = nil }
        }
    }
}
