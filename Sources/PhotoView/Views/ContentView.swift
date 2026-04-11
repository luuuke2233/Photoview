import SwiftUI
import AppKit

let appVersion = "1.5.7"

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.5) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .foregroundColor(configuration.isPressed ? .white : .primary)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ToolbarLabelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.5) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .foregroundColor(configuration.isPressed ? .white : .primary)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

@MainActor
func zoomWindow() {
    if let window = NSApp.keyWindow {
        window.zoom(nil)
    }
}

struct ContentView: View {
    @EnvironmentObject var lib: LibraryManager
    @StateObject private var toolbarManager = ToolbarManager.shared
    @State private var showImporter = false
    @State private var sidebarWidth: Double = 250
    @ObservedObject private var localization = LocalizationManager.shared
    
    var filterPickerWidth: CGFloat {
        localization.currentLanguage == .english ? 220 : 200
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomToolbar(
                toolbarManager: toolbarManager,
                localization: localization,
                filterPickerWidth: filterPickerWidth,
                showImporter: $showImporter,
                refreshAction: { Task { await lib.refreshCurrentFolder() } }
            )
            .frame(height: 44)
            .background(Color(nsColor: .windowBackgroundColor))
            .onTapGesture(count: 2) {
                zoomWindow()
            }
            .overlay(alignment: .bottom) {
                Divider()
            }
            
            HStack(spacing: 0) {
                SidebarView(emptyFolderTitle: localization.tr(LocalizedString.emptyFolder, LocalizedString_en.emptyFolder))
                    .frame(width: sidebarWidth, alignment: .leading)
                
                Divider()
                    .frame(width: 4)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { sidebarWidth = max(200, min(500, sidebarWidth + $0.translation.width)) }
                            .onEnded { _ in }
                    )
                
                MediaGridView(viewMode: toolbarManager.currentViewMode)
                    .frame(maxWidth: .infinity)
                    .onChange(of: lib.sortOption) { _, _ in lib.refreshFilter() }
                    .onChange(of: lib.filterOption) { _, _ in lib.refreshFilter() }
            }
        }
        .overlay(alignment: .top) {
            if toolbarManager.isCustomizing {
                ToolbarCustomizationPanel(toolbarManager: toolbarManager, localization: localization)
                    .padding(.top, 52)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder], allowsMultipleSelection: true) { if case .success(let u) = $0 { for url in u { Task { await lib.addFolder(url: url) } } } }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct CustomToolbar: View {
    @EnvironmentObject var lib: LibraryManager
    @ObservedObject var toolbarManager: ToolbarManager
    @ObservedObject var localization: LocalizationManager
    let filterPickerWidth: CGFloat
    @Binding var showImporter: Bool
    let refreshAction: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(toolbarManager.items) { item in
                toolbarItemView(for: item)
            }
            
            Spacer()
            
            Button(action: { toolbarManager.isCustomizing.toggle() }) {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.plain)
            .help("Customize Toolbar")
        }
        .padding(.horizontal, 16)
        .contextMenu {
            Button("Customize Toolbar...") {
                toolbarManager.isCustomizing = true
            }
            Divider()
            Button("Reset to Default") {
                toolbarManager.resetToDefault()
            }
        }
    }
    
    @ViewBuilder
    private func toolbarItemView(for item: ToolbarItem) -> some View {
        Group {
            switch item.type {
            case .refresh:
                Button(action: refreshAction) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help(localization.tr(LocalizedString.refresh, LocalizedString_en.refresh))
                
            case .addFolder:
                Button(action: { showImporter = true }) {
                    Label(localization.tr(LocalizedString.addFolder, LocalizedString_en.addFolder), systemImage: "folder.badge.plus")
                }
                .buttonStyle(ToolbarLabelButtonStyle())
                
            case .filter:
                Picker(localization.tr(LocalizedString.filter, LocalizedString_en.filter), selection: $lib.filterOption) {
                    ForEach(FilterOption.allCases) { option in
                        Text(localization.filterName(option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: filterPickerWidth)
                
            case .sort:
                Picker(localization.tr(LocalizedString.sort, LocalizedString_en.sort), selection: $lib.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(localization.sortName(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                
            case .viewMode:
                Menu {
                    ForEach(ViewMode.allCases) { mode in
                        Button(action: { toolbarManager.currentViewMode = mode }) {
                            HStack {
                                Image(systemName: mode.systemImage)
                                Text(mode.title)
                                if toolbarManager.currentViewMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: toolbarManager.currentViewMode.systemImage)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .buttonStyle(ToolbarButtonStyle())
                .help("View Mode")
                
            case .folderInfo:
                folderInfoView
            }
        }
        .buttonStyle(ToolbarButtonStyle())
    }
    
    @ViewBuilder
    private var folderInfoView: some View {
        let imageCount = lib.filteredItems.filter { $0.type == .image }.count
        let videoCount = lib.filteredItems.filter { $0.type == .video }.count
        let totalSize = lib.filteredItems.reduce(0) { $0 + $1.fileSize }
        
        HStack(spacing: 4) {
            if imageCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "photo")
                    Text("\(imageCount)")
                }
            }
            if videoCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "video")
                    Text("\(videoCount)")
                }
            }
            if totalSize > 0 {
                Text(formatFileSize(totalSize))
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ToolbarCustomizationPanel: View {
    @ObservedObject var toolbarManager: ToolbarManager
    @ObservedObject var localization: LocalizationManager
    @State private var draggingItem: ToolbarItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Items:")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    toolbarManager.isCustomizing = false
                }
            }
            
            ForEach(toolbarManager.items) { item in
                HStack {
                    Image(systemName: item.type.systemImage)
                        .frame(width: 20)
                    Text(itemTypeName(item.type))
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .onDrag {
                    draggingItem = item
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(of: [.text], delegate: ToolbarItemDropDelegate(
                    item: item,
                    items: $toolbarManager.items,
                    draggingItem: $draggingItem
                ))
                .contextMenu {
                    Button("Remove") {
                        toolbarManager.removeItem(item)
                    }
                }
            }
            
            Divider()
            
            Text("Available Items:")
                .font(.headline)
            
            ForEach(ToolbarItemType.allCases.filter { type in
                !toolbarManager.items.contains { $0.type == type }
            }) { type in
                HStack {
                    Image(systemName: type.systemImage)
                        .frame(width: 20)
                    Text(itemTypeName(type))
                    Spacer()
                    Button("Add") {
                        toolbarManager.addItem(type)
                    }
                }
                .padding(8)
            }
        }
        .padding()
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    private func itemTypeName(_ type: ToolbarItemType) -> String {
        switch type {
        case .refresh: return localization.tr(LocalizedString.refresh, LocalizedString_en.refresh)
        case .addFolder: return localization.tr(LocalizedString.addFolder, LocalizedString_en.addFolder)
        case .filter: return localization.tr(LocalizedString.filter, LocalizedString_en.filter)
        case .sort: return localization.tr(LocalizedString.sort, LocalizedString_en.sort)
        case .viewMode: return "View Mode"
        case .folderInfo: return "Folder Info"
        }
    }
}

struct ToolbarItemDropDelegate: DropDelegate {
    let item: ToolbarItem
    @Binding var items: [ToolbarItem]
    @Binding var draggingItem: ToolbarItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        withAnimation {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var lib: LibraryManager
    @State private var expandedFolders: Set<UUID> = []
    let emptyFolderTitle: String
    
    var body: some View {
        ZStack {
            List {
                ForEach(lib.rootFolders) { root in
                    FolderRow(expandedFolders: $expandedFolders, node: root, isRoot: true, emptyFolderTitle: emptyFolderTitle)
                }
            }
            .listStyle(.sidebar)
            
            if lib.isScanningFolder {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在加载: \(lib.scanningFolderName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            }
        }
    }
}

struct FolderRow: View {
    @EnvironmentObject var lib: LibraryManager
    @Binding var expandedFolders: Set<UUID>
    let node: FolderNode
    let isRoot: Bool
    let emptyFolderTitle: String
    
    var isSelected: Bool { lib.selectedFolder?.id == node.id }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if !node.children.isEmpty {
                    Button(action: {
                        if expandedFolders.contains(node.id) { expandedFolders.remove(node.id) }
                        else {
                            expandedFolders.insert(node.id)
                            Task { await lib.expandFolder(node) }
                        }
                    }) {
                        Image(systemName: expandedFolders.contains(node.id) ? "chevron.down" : "chevron.right")
                            .font(.caption).foregroundColor(.secondary).frame(width: 16)
                    }.buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 16)
                }
                
                Button(action: { 
                    if node.isAvailable {
                        lib.selectFolder(node) 
                    }
                }) {
                    HStack {
                        Image(systemName: "folder.fill").foregroundColor(node.isAvailable ? .blue : .gray)
                        Text(node.name).foregroundColor(node.isAvailable ? .primary : .gray).lineLimit(1)
                        Spacer()
                        if isRoot {
                            Button(action: { lib.removeFolder(node) }) {
                                Image(systemName: "trash")
                            }.buttonStyle(.plain).foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .background(lib.isDragTargetFolder?.id == node.id ? Color.blue.opacity(0.2) : Color.clear)
                .contextMenu {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.url.path)
                    }
                }
                .onDrop(of: [.text], delegate: FolderDropDelegate(node: node, lib: lib))
            }
            
            if expandedFolders.contains(node.id) {
                ForEach(node.children) { child in
                    FolderRow(expandedFolders: $expandedFolders, node: child, isRoot: false, emptyFolderTitle: emptyFolderTitle)
                        .padding(.leading, 16)
                }
                if node.children.isEmpty && node.isScanned {
                    Text(emptyFolderTitle).font(.caption).foregroundColor(.secondary).padding(.leading, 32)
                }
            }
        }
    }
}

struct FolderDropDelegate: DropDelegate {
    let node: FolderNode
    let lib: LibraryManager
    
    func dropEntered(info: DropInfo) {
        if lib.isDragTargetFolder?.id != node.id {
            lib.isDragTargetFolder = node
        }
    }
    
    func dropExited(info: DropInfo) {
        if lib.isDragTargetFolder?.id == node.id {
            lib.isDragTargetFolder = nil
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard node.isAvailable else { return false }
        guard !lib.selectedMedia.isEmpty else { return false }
        
        Task {
            let success = await lib.moveSelectedItems(to: node)
            lib.isDragTargetFolder = nil
        }
        
        return true
    }
}
