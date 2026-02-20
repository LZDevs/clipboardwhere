import SwiftUI

enum ClipboardTab: String, CaseIterable {
    case all = "All"
    case pinned = "Pinned"
}

struct ClipboardListView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var panelState: PanelState
    let onDismiss: () -> Void
    let onPaste: (ClipboardItem) -> Void

    @State private var searchText = ""
    @State private var activeTab: ClipboardTab = .all

    private var filteredItems: [ClipboardItem] {
        let base = activeTab == .pinned ? store.pinnedItems : store.items
        if searchText.isEmpty {
            return base
        }
        return base.filter {
            !$0.isImage && $0.text.localizedCaseInsensitiveContains(searchText)
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
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                VStack(spacing: 0) {
                                    if index > 0 {
                                        Divider()
                                            .opacity(0.3)
                                            .padding(.horizontal, 12)
                                    }
                                    ItemRow(
                                        item: item,
                                        isSelected: index == panelState.selectedIndex,
                                        shortcutLabel: shortcutLabel(for: index),
                                        onSelect: { onPaste(item) },
                                        onPin: { store.togglePin(item) },
                                        onDelete: { store.delete(item) }
                                    )
                                }
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
                    onPaste(item)
                }
            }
        }
        .onChange(of: panelState.quickPastePinnedIndex) { index in
            if let index = index {
                panelState.quickPastePinnedIndex = nil
                if let item = store.pinnedItems[safe: index] {
                    onPaste(item)
                }
            }
        }
        .onChange(of: searchText) { _ in
            panelState.selectedIndex = 0
            panelState.isSearching = !searchText.isEmpty
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

    private func shortcutLabel(for index: Int) -> String? {
        guard !panelState.isSearching else { return nil }
        if activeTab == .pinned && index < 9 {
            return "\u{2318}\(index + 1)"
        }
        if activeTab == .all && index < 5 {
            return "\(index + 1)"
        }
        return nil
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let shortcutLabel: String?
    let onSelect: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let label = shortcutLabel {
                Text(label)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28)
                    .padding(.top, 2)
            } else {
                Spacer().frame(width: 28)
            }

            if item.isImage {
                imageContent
            } else {
                textContent
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

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.preview)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.primary)

            Text(relativeTime(item.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var imageContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let url = item.imageURL, let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 50, maxHeight: 50)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                }

                Text("Image")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }

            Text(relativeTime(item.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        let days = hours / 24
        if days == 1 { return "yesterday" }
        if days < 30 { return "\(days) days ago" }
        let months = days / 30
        if months < 12 { return "\(months) mo ago" }
        let years = months / 12
        return "\(years) yr ago"
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
