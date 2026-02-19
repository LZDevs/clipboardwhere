import SwiftUI

enum ClipboardTab: String, CaseIterable {
    case all = "All"
    case pinned = "Pinned"
}

struct ClipboardListView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var panelState: PanelState
    let onDismiss: () -> Void
    let onPaste: (String) -> Void

    @State private var searchText = ""
    @State private var activeTab: ClipboardTab = .all

    private var filteredItems: [ClipboardItem] {
        let base = activeTab == .pinned ? store.pinnedItems : store.items
        if searchText.isEmpty {
            return base
        }
        return base.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Item list
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    if activeTab == .pinned {
                        Text("No pinned items")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    } else {
                        Text(store.items.isEmpty ? "No clipboard history yet" : "No matches")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                ItemRow(
                                    item: item,
                                    isSelected: index == panelState.selectedIndex,
                                    index: index,
                                    onSelect: { onPaste(item.text) },
                                    onPin: { store.togglePin(item) },
                                    onDelete: { store.delete(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: panelState.selectedIndex) { newIndex in
                        if let item = filteredItems[safe: newIndex] {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer with tabs
            HStack(spacing: 0) {
                ForEach(ClipboardTab.allCases, id: \.self) { tab in
                    Button(action: {
                        activeTab = tab
                        panelState.selectedIndex = 0
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab == .all ? "clock" : "pin.fill")
                                .font(.system(size: 10))
                            Text(tab.rawValue)
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .foregroundColor(activeTab == tab ? .accentColor : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(activeTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: {
                    if let url = URL(string: Constants.repoURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("About ClipboardWhere")
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 360, height: 420)
        .background(VisualEffectView())
        .cornerRadius(10)
        .onChange(of: panelState.pasteRequested) { requested in
            if requested {
                panelState.pasteRequested = false
                if let item = filteredItems[safe: panelState.selectedIndex] {
                    onPaste(item.text)
                }
            }
        }
        .onChange(of: searchText) { _ in
            panelState.selectedIndex = 0
            panelState.filteredCount = filteredItems.count
        }
        .onChange(of: activeTab) { _ in
            panelState.filteredCount = filteredItems.count
        }
        .onChange(of: panelState.toggleTab) { toggle in
            if toggle {
                panelState.toggleTab = false
                activeTab = activeTab == .all ? .pinned : .all
                panelState.selectedIndex = 0
            }
        }
        .onAppear {
            panelState.filteredCount = filteredItems.count
        }
        .onChange(of: store.items.count) { _ in
            panelState.filteredCount = filteredItems.count
        }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let index: Int
    let onSelect: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28)
                    .padding(.top, 2)
            } else {
                Spacer().frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(item.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Pin & delete icons on hover
            if isHovered || item.isPinned {
                HStack(spacing: 4) {
                    Button(action: onPin) {
                        Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundColor(item.isPinned ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin" : "Pin")

                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) :
                      isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Visual Effect (vibrancy)

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Safe array subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
