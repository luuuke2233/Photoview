import SwiftUI

let appVersion = "1.4.0"

struct ContentView: View {
    @EnvironmentObject var lib: LibraryManager
    @State private var showImporter = false
    @State private var sidebarWidth: Double = 250
    @ObservedObject private var localization = LocalizationManager.shared
    
    var filterPickerWidth: CGFloat {
        localization.currentLanguage == .english ? 220 : 180
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
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
                
                MediaGridView()
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) { Button(action: {
                            Task { await lib.refreshCurrentFolder() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }.help(localization.tr(LocalizedString.refresh, LocalizedString_en.refresh))}
                        ToolbarItem(placement: .primaryAction) { Button(localization.tr(LocalizedString.addFolder, LocalizedString_en.addFolder), systemImage: "folder.badge.plus") { showImporter = true } }
                        ToolbarItem(placement: .primaryAction) { 
                            Picker(localization.tr(LocalizedString.filter, LocalizedString_en.filter), selection: $lib.filterOption) { 
                                ForEach(FilterOption.allCases) { option in
                                    Text(localization.filterName(option)).tag(option)
                                }
                            }.pickerStyle(.segmented).frame(width: filterPickerWidth) 
                        }
                        ToolbarItem(placement: .primaryAction) { 
                            Picker(localization.tr(LocalizedString.sort, LocalizedString_en.sort), selection: $lib.sortOption) { 
                                ForEach(SortOption.allCases) { option in
                                    Text(localization.sortName(option)).tag(option)
                                }
                            }.pickerStyle(.menu) 
                        }
                    }
                    .onChange(of: lib.sortOption) { _, _ in lib.refreshFilter() }
                    .onChange(of: lib.filterOption) { _, _ in lib.refreshFilter() }
            }
            
            Text("v\(appVersion)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(8)
                .allowsHitTesting(false)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder], allowsMultipleSelection: true) { if case .success(let u) = $0 { u.forEach { lib.addFolder(url: $0) } } }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct SidebarView: View {
    @EnvironmentObject var lib: LibraryManager
    @State private var expandedFolders: Set<UUID> = []
    let emptyFolderTitle: String
    
    var body: some View {
        List {
            ForEach(lib.rootFolders) { root in
                FolderRow(expandedFolders: $expandedFolders, node: root, isRoot: true, emptyFolderTitle: emptyFolderTitle)
            }
        }
        .listStyle(.sidebar)
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
                if !node.isScanned || !node.children.isEmpty {
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
                        if node.mediaCount > 0 {
                            Text("(\(node.mediaCount))").font(.caption).foregroundColor(.secondary)
                        }
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
