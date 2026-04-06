import SwiftUI

struct MediaGridView: View {
    @EnvironmentObject var lib: LibraryManager
    @State private var gridSize: Double = 140
    @State private var lastScale: CGFloat = 1.0
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        Group {
            if lib.isLoading && lib.filteredItems.isEmpty {
                VStack { ProgressView(); Text(localization.tr(LocalizedString.scanning, LocalizedString_en.scanning)) }
            } else if lib.filteredItems.isEmpty && !lib.isLoading {
                ContentUnavailableView(localization.tr(LocalizedString.noMedia, LocalizedString_en.noMedia), systemImage: "photo", description: Text(localization.tr(LocalizedString.noMediaDescription, LocalizedString_en.noMediaDescription)))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: gridSize, maximum: 300))], spacing: 8) {
                        ForEach(lib.filteredItems) { item in
                            MediaCell(item: item, gridSize: gridSize)
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
        }
    }
    
    private func openFS(item: MediaMetadata) {
        let fullItem = MediaItem(url: item.url)
        let allItems = lib.filteredItems.map { MediaItem(url: $0.url) }
        FullscreenWindowController.shared.show(item: fullItem, in: allItems)
    }
}

struct MediaCell: View {
    let item: MediaMetadata
    let gridSize: Double
    @EnvironmentObject var lib: LibraryManager
    @State private var thumb: NSImage?
    
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
        }
        .aspectRatio(1, contentMode: .fit)
        .task { thumb = lib.getThumbnail(for: item, size: CGSize(width: 256, height: 256)) }
    }
}
