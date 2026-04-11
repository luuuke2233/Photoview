import SwiftUI

struct MediaGridView: View {
    @EnvironmentObject var lib: LibraryManager
    @State private var gridSize: Double = 140
    @State private var lastScale: CGFloat = 1.0
    @ObservedObject private var localization = LocalizationManager.shared
    let viewMode: ViewMode
    
    var body: some View {
        Group {
            if lib.isLoading && lib.filteredItems.isEmpty {
                VStack { ProgressView(); Text(localization.tr(LocalizedString.scanning, LocalizedString_en.scanning)) }
            } else if lib.filteredItems.isEmpty && !lib.isLoading {
                ContentUnavailableView(localization.tr(LocalizedString.noMedia, LocalizedString_en.noMedia), systemImage: "photo", description: Text(localization.tr(LocalizedString.noMediaDescription, LocalizedString_en.noMediaDescription)))
            } else {
                switch viewMode {
                case .grid:
                    gridView
                case .list:
                    listView
                }
            }
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: gridSize, maximum: 300))], spacing: 8) {
                ForEach(lib.filteredItems) { item in
                    MediaCell(item: item, gridSize: gridSize)
                        .id(item.id)
                        .onTapGesture(count: 2) { openFS(item: item) }
                        .contextMenu {
                            Button(action: { lib.openInFinder(url: item.url) }) {
                                Label(localization.tr(LocalizedString.showInFinder, LocalizedString_en.showInFinder), systemImage: "folder")
                            }
                        }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        gridSize = max(80, min(300, gridSize * (value / lastScale)))
                        lastScale = value
                    }
                    .onEnded { _ in lastScale = 1.0 }
            )
            .onAppear {
                if lib.hasMore && !lib.isLoading {
                    lib.loadNextPage()
                }
            }
        }
    }
    
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(lib.filteredItems) { item in
                    MediaListCell(item: item)
                        .onTapGesture(count: 2) { openFS(item: item) }
                        .contextMenu {
                            Button(action: { lib.openInFinder(url: item.url) }) {
                                Label(localization.tr(LocalizedString.showInFinder, LocalizedString_en.showInFinder), systemImage: "folder")
                            }
                        }
                }
            }
            .onAppear {
                if lib.hasMore && !lib.isLoading {
                    lib.loadNextPage()
                }
            }
        }
    }
    
    private func openFS(item: MediaMetadata) {
        let fullItem = MediaItem(url: item.url)
        
        if fullItem.type == .video {
            let videoItems = lib.filteredItems
                .filter { MediaItem(url: $0.url).type == .video }
                .map { MediaItem(url: $0.url) }
            FullscreenWindowController.shared.show(item: fullItem, in: videoItems)
            return
        }
        
        let allItems = lib.filteredItems.map { MediaItem(url: $0.url) }
        FullscreenWindowController.shared.show(item: fullItem, in: allItems)
    }
}

struct MediaCell: View {
    let item: MediaMetadata
    let gridSize: Double
    @EnvironmentObject var lib: LibraryManager
    @State private var thumb: NSImage?
    @State private var isShiftPressed = false
    
    private var isSelected: Bool { lib.isSelected(item) }
    private var hasSelection: Bool { !lib.selectedMedia.isEmpty }
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width
            ZStack {
                Color(NSColor.controlBackgroundColor)
                if let t = thumb {
                    Image(nsImage: t)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    Image(systemName: item.type == .image ? "photo" : "video")
                        .font(.system(size: size * 0.25))
                        .foregroundColor(.secondary)
                }
                if item.type == .video {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: size * 0.15))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .padding(size * 0.03)
                        }
                        Spacer()
                    }
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture(count: 1) {
            let addToSelection = NSEvent.modifierFlags.contains(.shift) && lib.lastSelectedMediaId != nil
            lib.handleClickSelection(for: item, addToSelection: addToSelection)
        }
        .onDrag {
            if isSelected {
                return NSItemProvider(object: "selected-media" as NSString)
            }
            return NSItemProvider(object: item.url.path as NSString)
        }
        .task { thumb = await lib.getThumbnail(for: item, size: CGSize(width: 256, height: 256)) }
    }
}

struct MediaListCell: View {
    let item: MediaMetadata
    @EnvironmentObject var lib: LibraryManager
    @State private var thumb: NSImage?
    
    private var isSelected: Bool { lib.isSelected(item) }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                if let t = thumb {
                    Image(nsImage: t)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                } else {
                    Image(systemName: item.type == .image ? "photo" : "video")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                if item.type == .video {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 14))
                    .lineLimit(1)
                Text(formatDate(item.modificationDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatFileSize(item.fileSize))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .onTapGesture(count: 1) {
            let addToSelection = NSEvent.modifierFlags.contains(.shift) && lib.lastSelectedMediaId != nil
            lib.handleClickSelection(for: item, addToSelection: addToSelection)
        }
        .task { thumb = await lib.getThumbnail(for: item, size: CGSize(width: 120, height: 120)) }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}