import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO
import AVFoundation
import SQLite3
import WebKit

struct FolderNode: Identifiable, Equatable, Hashable {
    let id: UUID; let url: URL; let name: String
    var children: [FolderNode] = []; var mediaCount: Int = 0
    var isScanned: Bool = false
    var isAvailable: Bool = true
    static func == (l: FolderNode, r: FolderNode) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct MediaMetadata: Identifiable {
    let id: UUID = UUID()
    let url: URL; let type: MediaType; let modificationDate: Date; let fileSize: Int64
}

@MainActor
class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    @Published var rootFolders: [FolderNode] = []
    @Published var selectedRootFolder: FolderNode?
    @Published var selectedFolder: FolderNode?
    @Published var filteredItems: [MediaMetadata] = []
    @Published var selectedMedia: Set<UUID> = []
    @Published var lastSelectedMediaId: UUID? = nil
    @Published var isDragTargetFolder: FolderNode? = nil
    @Published var isLoading = false
    @Published var isScanningFolder = false
    @Published var scanningFolderName = ""
    @Published var progress: Double = 0.0
    @Published var sortOption: SortOption = .dateNewest
    @Published var filterOption: FilterOption = .all
    
    private var scanningTask: Task<Void, Never>?
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private var db: OpaquePointer?
    private let pageSize = 200
    private let maxLoadedItems = 1000
    private var currentOffset = 0
    var hasMore = true
    private var folderWatchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var currentWatchedFolderId: UUID?
    
    init() {
        thumbnailCache.countLimit = 500
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
        openDB()
        Task { await loadFolders() }
    }
    
    private func openDB() {
        let dbPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhotoView").appendingPathComponent("metadata.db")
        try? FileManager.default.createDirectory(at: dbPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        if sqlite3_open(dbPath.path, &db) == SQLITE_OK {
            sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS media (
                id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT UNIQUE NOT NULL,
                type TEXT NOT NULL, modDate REAL NOT NULL, fileSize INTEGER NOT NULL, folderPath TEXT NOT NULL
            ); CREATE INDEX IF NOT EXISTS idx_folder ON media(folderPath);
            """, nil, nil, nil)
        }
    }
    
    func addFolder(url: URL) async {
        guard !rootFolders.contains(where: { $0.url == url }) else { return }
        
        isScanningFolder = true
        scanningFolderName = url.lastPathComponent
        
        let acc = url.startAccessingSecurityScopedResource()
        defer { if acc { url.stopAccessingSecurityScopedResource() } }
        
        var node = FolderNode(id: UUID(), url: url, name: url.lastPathComponent)
        
        scanningTask = Task {
            await scanStructureRecursive(node: &node, depth: 0, maxDepth: 10)
            node.isScanned = true
            
            if !Task.isCancelled {
                await MainActor.run {
                    rootFolders.append(node)
                    self.isScanningFolder = false
                    self.scanningFolderName = ""
                    self.saveFolders()
                    self.selectedRootFolder = node
                    self.selectedFolder = node
                    self.currentWatchedFolderId = node.id
                    self.resetAndLoadItems()
                    self.startWatching(folder: node)
                }
            }
        }
        
        await scanningTask?.value
    }
    
    func cancelScanFolder() {
        scanningTask?.cancel()
        scanningTask = nil
        isScanningFolder = false
        scanningFolderName = ""
    }
    
    func removeFolder(_ node: FolderNode) {
        if currentWatchedFolderId == node.id {
            stopWatching(folderId: node.id)
            currentWatchedFolderId = nil
        }
        removeNodeFromTree(node)
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM media WHERE folderPath = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (node.url.standardizedFileURL.path as NSString).utf8String, -1, nil)
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
        saveFolders()
        if selectedFolder?.id == node.id {
            selectedFolder = rootFolders.first
            selectedRootFolder = rootFolders.first
            resetAndLoadItems()
            if let newFolder = rootFolders.first {
                currentWatchedFolderId = newFolder.id
                if newFolder.isAvailable { startWatching(folder: newFolder) }
            }
        }
    }
    
    private func removeNodeFromTree(_ node: FolderNode) {
        if let idx = rootFolders.firstIndex(where: { $0.id == node.id }) {
            rootFolders.remove(at: idx); return
        }
        for i in 0..<rootFolders.count {
            if let childIdx = rootFolders[i].children.firstIndex(where: { $0.id == node.id }) {
                rootFolders[i].children.remove(at: childIdx); return
            }
        }
    }
    
    func openInFinder(url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    
    func selectFolder(_ node: FolderNode) {
        if currentWatchedFolderId != node.id {
            if let oldId = currentWatchedFolderId { stopWatching(folderId: oldId) }
            currentWatchedFolderId = node.id
            if node.isAvailable {
                startWatching(folder: node)
            }
        }
        selectedFolder = node
        if rootFolders.contains(where: { $0.id == node.id }) { selectedRootFolder = node }
        if let existingNode = findNodeInTree(node.id) {
            if !existingNode.isScanned {
                Task { await scanAndLoadLevel(node: existingNode) }
            } else {
                resetAndLoadItems()
            }
        } else {
            resetAndLoadItems()
        }
    }
    
    private func resetAndLoadItems() { 
        currentOffset = 0 
        hasMore = true 
        filteredItems = [] 
        loadNextPage() 
    }
    
    func loadNextPage() {
        guard hasMore, let folder = selectedFolder else { return }
        guard filteredItems.count < maxLoadedItems else { hasMore = false; return }
        isLoading = true
        let items = queryItems(folder: folder, offset: currentOffset, limit: pageSize)
        filteredItems.append(contentsOf: items)
        currentOffset += items.count; 
        hasMore = items.count == pageSize && filteredItems.count < maxLoadedItems; 
        isLoading = false
    }
    
    func refreshFilter() { resetAndLoadItems() }
    
    private func queryItems(folder: FolderNode, offset: Int, limit: Int) -> [MediaMetadata] {
        let path = folder.url.standardizedFileURL.path
        var stmt: OpaquePointer?
        var sql = "SELECT path, type, modDate, fileSize FROM media WHERE folderPath = ?"
        switch filterOption {
        case .all: break
        case .images: sql += " AND type = 'image'"
        case .videos: sql += " AND type = 'video'"
        }
        switch sortOption {
        case .nameAsc: sql += " ORDER BY path ASC"
        case .nameDesc: sql += " ORDER BY path DESC"
        case .dateNewest: sql += " ORDER BY modDate DESC"
        case .dateOldest: sql += " ORDER BY modDate ASC"
        case .sizeLargest: sql += " ORDER BY fileSize DESC"
        case .sizeSmallest: sql += " ORDER BY fileSize ASC"
        }
        sql += " LIMIT ? OFFSET ?"
        
        var items: [MediaMetadata] = []
        let prefix = path + "/"
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(limit)); sqlite3_bind_int(stmt, 3, Int32(offset))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let cString = sqlite3_column_text(stmt, 0) else { continue }
                let filePath = String(cString: cString)
                guard filePath.hasPrefix(prefix) else { continue }
                let relativePath = String(filePath.dropFirst(prefix.count))
                guard !relativePath.contains("/") else { continue }
                
                let typeStr = String(cString: sqlite3_column_text(stmt, 1)!)
                let modDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                let fileSize = sqlite3_column_int64(stmt, 3)
                items.append(MediaMetadata(url: URL(fileURLWithPath: filePath), type: MediaType(rawValue: typeStr) ?? .image, modificationDate: modDate, fileSize: fileSize))
            }
        }
        sqlite3_finalize(stmt); return items
    }
    
    private func saveFolders() {
        let bookmarks = rootFolders.compactMap { try? $0.url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }
        UserDefaults.standard.set(bookmarks, forKey: "SavedFolderBookmarks")
        
        let folderStructures = rootFolders.map { folderToStruct($0) }
        if let data = try? JSONEncoder().encode(folderStructures) {
            UserDefaults.standard.set(data, forKey: "SavedFolderStructures")
        }
    }
    
    private struct FolderStruct: Codable {
        let id: String
        let name: String
        let isScanned: Bool
        let children: [FolderStruct]
    }
    
    private func folderToStruct(_ node: FolderNode) -> FolderStruct {
        FolderStruct(
            id: node.id.uuidString,
            name: node.name,
            isScanned: node.isScanned,
            children: node.children.map { folderToStruct($0) }
        )
    }
    
    private func folderFromStruct(_ struct_: FolderStruct, url: URL) -> FolderNode {
        var node = FolderNode(id: UUID(uuidString: struct_.id) ?? UUID(), url: url, name: struct_.name)
        node.isScanned = struct_.isScanned
        node.children = struct_.children.map { childStruct in
            let childURL = url.appendingPathComponent(childStruct.name)
            return folderFromStruct(childStruct, url: childURL)
        }
        return node
    }
    
    // 优化：优先加载选中的文件夹，后台加载其他文件夹
    private func loadFolders() async {
        guard let savedBookmarks = UserDefaults.standard.array(forKey: "SavedFolderBookmarks") as? [Data] else { return }
        
        var savedStructures: [FolderStruct] = []
        if let data = UserDefaults.standard.data(forKey: "SavedFolderStructures") {
            savedStructures = (try? JSONDecoder().decode([FolderStruct].self, from: data)) ?? []
        }
        
        var loadedFolders: [FolderNode] = []
        for (index, data) in savedBookmarks.enumerated() {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
                var isAvailable = FileManager.default.fileExists(atPath: url.path)
                if !isAvailable && isStale {
                    if let newData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        let newURL = try URL(resolvingBookmarkData: newData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
                        isAvailable = FileManager.default.fileExists(atPath: newURL.path)
                        if isAvailable {
                            let acc = newURL.startAccessingSecurityScopedResource()
                            if acc {
                                let node: FolderNode
                                if index < savedStructures.count {
                                    node = folderFromStruct(savedStructures[index], url: newURL)
                                } else {
                                    node = FolderNode(id: UUID(), url: newURL, name: newURL.lastPathComponent, isAvailable: true)
                                }
                                loadedFolders.append(node)
                            }
                            continue
                        }
                    }
                }
                if isAvailable {
                    let acc = url.startAccessingSecurityScopedResource()
                    if acc {
                        let node: FolderNode
                        if index < savedStructures.count {
                            node = folderFromStruct(savedStructures[index], url: url)
                        } else {
                            node = FolderNode(id: UUID(), url: url, name: url.lastPathComponent, isAvailable: true)
                        }
                        loadedFolders.append(node)
                    }
                } else {
                    loadedFolders.append(FolderNode(id: UUID(), url: url, name: url.lastPathComponent, isAvailable: false))
                }
            } catch { print("Failed to resolve bookmark: \(error)") }
        }
        rootFolders = loadedFolders
        if let f = rootFolders.first { 
            selectedRootFolder = f; 
            selectedFolder = f 
            resetAndLoadItems()
        }
        
        // 后台扫描未扫描的文件夹
        Task {
            await withTaskGroup(of: (UUID, FolderNode).self) { group in
                for var node in rootFolders where node.isAvailable && !node.isScanned {
                    group.addTask {
                        await self.scanStructure(node: &node)
                        return (node.id, node)
                    }
                }
                for await (id, updatedNode) in group {
                    if let idx = self.rootFolders.firstIndex(where: { $0.id == id }) {
                        self.rootFolders[idx] = updatedNode
                    }
                }
            }
        }
    }
    
    // 优先扫描指定文件夹
    private func priorityScanFolder(folderId: UUID) async {
        guard let idx = rootFolders.firstIndex(where: { $0.id == folderId }) else { return }
        var node = rootFolders[idx]
        await scanFolderInternal(&node)
        rootFolders[idx] = node
    }
    
    func refreshFolderStatus() async {
        for i in 0..<rootFolders.count {
            let url = rootFolders[i].url
            let exists = FileManager.default.fileExists(atPath: url.path)
            if rootFolders[i].isAvailable != exists {
                if exists {
                    let acc = url.startAccessingSecurityScopedResource()
                    if acc {
                        var node = rootFolders[i]
                        node.isAvailable = true
                        await scanFolderInternal(&node)
                        rootFolders[i] = node
                    }
                } else {
                    rootFolders[i].isAvailable = false
                }
            }
        }
    }
    
    func refreshCurrentFolder() async {
        guard let folder = selectedFolder else { return }
        let folderPath = folder.url.standardizedFileURL.path
        deleteMediaInFolder(path: folderPath)
        thumbnailCache.removeAllObjects()
        currentOffset = 0
        hasMore = true
        filteredItems = []
        if var node = findNodeInTree(folder.id) {
            await scanFolderInternal(&node)
            updateNodeInTree(node)
            loadNextPage()
        }
    }
    
    private func deleteMediaInFolder(path: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM media WHERE folderPath = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }
    
    @MainActor func buildTree() async {
        rootFolders = rootFolders.map { var n = $0; n.isScanned = false; n.mediaCount = 0; return n }
        if let f = rootFolders.first { selectedRootFolder = f; selectedFolder = f }
        resetAndLoadItems()
    }
    
    private func scanAndLoadLevel(node: FolderNode) async {
        if var n = findNodeInTree(node.id) {
            await scanFolderInternal(&n)
            updateNodeInTree(n)
            resetAndLoadItems()
        }
    }
    
    func expandFolder(_ node: FolderNode) async { await scanAndLoadLevel(node: node) }
    
    func startWatching(folder: FolderNode) {
        stopWatching(folderId: folder.id)
        let fd = open(folder.url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename, .extend], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshCurrentFolder()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        folderWatchers[folder.id] = source
    }
    
    func stopWatching(folderId: UUID) {
        folderWatchers[folderId]?.cancel()
        folderWatchers.removeValue(forKey: folderId)
    }
    
    func stopAllWatching() {
        folderWatchers.values.forEach { $0.cancel() }
        folderWatchers.removeAll()
    }
    
    // 内部扫描逻辑（支持并行调用）
    private func scanFolderInternal(_ node: inout FolderNode) async {
        await scanStructure(node: &node)
        await scanMedia(node: &node)
    }
    
    private func findNodeInTree(_ id: UUID) -> FolderNode? {
        if let n = rootFolders.first(where: { $0.id == id }) { return n }
        for root in rootFolders { if let n = findInChildren(root.children, id) { return n } }
        return nil
    }
    private func findInChildren(_ children: [FolderNode], _ id: UUID) -> FolderNode? {
        for child in children {
            if child.id == id { return child }
            if let n = findInChildren(child.children, id) { return n }
        }
        return nil
    }
    
    private func updateNodeInTree(_ node: FolderNode) {
        for i in 0..<rootFolders.count {
            if rootFolders[i].id == node.id {
                rootFolders[i] = node
                return
            }
        }
        updateInChildren(&rootFolders, node)
    }
    private func updateInChildren(_ roots: inout [FolderNode], _ node: FolderNode) {
        for i in 0..<roots.count {
            if roots[i].id == node.id {
                roots[i] = node
                return
            }
            if let idx = roots[i].children.firstIndex(where: { $0.id == node.id }) {
                roots[i].children[idx] = node
                return
            }
            updateInChildren(&roots[i].children, node)
        }
    }
    
    private func scanStructure(node: inout FolderNode) async {
    }
    
    private func scanStructureRecursive(node: inout FolderNode, depth: Int, maxDepth: Int) async {
        if depth >= maxDepth { return }
        
        let acc = node.url.startAccessingSecurityScopedResource()
        defer { if acc { node.url.stopAccessingSecurityScopedResource() } }
        guard acc else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: node.url, includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey], options: [.skipsHiddenFiles])
            var subs: [FolderNode] = []
            for url in contents {
                let res = try? url.resourceValues(forKeys: [.isDirectoryKey])
                if res?.isDirectory == true {
                    var child = FolderNode(id: UUID(), url: url, name: url.lastPathComponent)
                    await scanStructureRecursive(node: &child, depth: depth + 1, maxDepth: maxDepth)
                    subs.append(child)
                }
            }
            node.children = subs.sorted { $0.name < $1.name }
        } catch {}
    }
    
    private func scanMedia(node: inout FolderNode) async {
        let acc = node.url.startAccessingSecurityScopedResource()
        defer { if acc { node.url.stopAccessingSecurityScopedResource() } }
        guard acc else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: node.url, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])
            var batch: [(String, String, Date, Int64, String)] = []
            let folderPath = node.url.standardizedFileURL.path
            
            for url in contents {
                let res = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey])
                if res?.isRegularFile == true, let type = MediaType.detectType(for: url) {
                    let modDate = res?.contentModificationDate ?? Date.distantPast
                    let size = Int64(res?.fileSize ?? 0)
                    batch.append((url.path, type.rawValue, modDate, size, folderPath))
                    if batch.count >= 500 { insertBatch(batch); batch.removeAll() }
                }
            }
            if !batch.isEmpty { insertBatch(batch) }
            node.mediaCount = countMediaInFolder(path: folderPath)
            node.isScanned = true
        } catch {}
    }
    
    private func countMediaInFolder(path: String) -> Int {
        var stmt: OpaquePointer?; var count = 0
        let sql = "SELECT COUNT(*) FROM media WHERE folderPath = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
            sqlite3_finalize(stmt)
        }
        return count
    }
    
    private func insertBatch(_ batch: [(String, String, Date, Int64, String)]) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR IGNORE INTO media (path, type, modDate, fileSize, folderPath) VALUES (?, ?, ?, ?, ?)"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
            for (path, type, modDate, size, folder) in batch {
                sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (type as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, modDate.timeIntervalSince1970)
                sqlite3_bind_int64(stmt, 4, size)
                sqlite3_bind_text(stmt, 5, (folder as NSString).utf8String, -1, nil)
                sqlite3_step(stmt); sqlite3_reset(stmt)
            }
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }
        sqlite3_finalize(stmt)
    }
    
    func getThumbnail(for item: MediaMetadata, size: CGSize) async -> NSImage? {
        let k = "\(item.url.path)-\(size.width)" as NSString
        if let c = thumbnailCache.object(forKey: k) { return c }
        let t = await genThumb(url: item.url, type: item.type, size: size)
        if let t { thumbnailCache.setObject(t, forKey: k) }; return t
    }
    
    func getFullImage(for item: MediaMetadata) -> NSImage? {
        guard item.type == .image else { return nil }
        guard let data = try? Data(contentsOf: item.url) else { return nil }
        return NSImage(data: data)
    }
    
    private func genThumb(url: URL, type: MediaType, size: CGSize) async -> NSImage? {
        let ext = url.pathExtension.lowercased()
        
        if type == .image {
            let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height) * 2]
            guard let s = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateThumbnailAtIndex(s, 0, o as CFDictionary) else { return nil }
            return NSImage(cgImage: cg, size: .zero)
        } else if ext == "webm" || ext == "avi" {
            return await genFFmpegThumb(url: url, size: size)
        } else {
            let g = AVAssetImageGenerator(asset: AVURLAsset(url: url)); g.appliesPreferredTrackTransform = true; g.maximumSize = CGSize(width: size.width * 2, height: size.height * 2)
            if let cg = try? g.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil) {
                return NSImage(cgImage: cg, size: .zero)
            }
            return await genFFmpegThumb(url: url, size: size)
        }
    }
    
    private func genFFmpegThumb(url: URL, size: CGSize) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard let ffmpegURL = Self.findExecutable(named: "ffmpeg") else { return nil }
            let thumbDir = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoViewThumbs", isDirectory: true)
            try? FileManager.default.createDirectory(at: thumbDir, withIntermediateDirectories: true)
            
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let modTime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let outputURL = thumbDir.appendingPathComponent("\(abs(url.path.hashValue))-\(Int(modTime))-\(Int(size.width))x\(Int(size.height)).png")
            
            if FileManager.default.fileExists(atPath: outputURL.path), let image = NSImage(contentsOf: outputURL) {
                return image
            }
            
            let maxWidth = max(Int(size.width * 2), 240)
            let maxHeight = max(Int(size.height * 2), 240)
            let process = Process()
            process.executableURL = ffmpegURL
            process.arguments = [
                "-hide_banner", "-loglevel", "error",
                "-y",
                "-ss", "00:00:01.000",
                "-i", url.path,
                "-frames:v", "1",
                "-vf", "scale=\(maxWidth):\(maxHeight):force_original_aspect_ratio=decrease",
                outputURL.path
            ]
            
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                return NSImage(contentsOf: outputURL)
            } catch {
                return nil
            }
        }.value
    }
    func closeDB() { sqlite3_close(db) }
    
    nonisolated private static func findExecutable(named name: String) -> URL? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    func toggleSelection(for item: MediaMetadata) {
        if selectedMedia.contains(item.id) {
            selectedMedia.remove(item.id)
        } else {
            selectedMedia.insert(item.id)
        }
    }
    
    func isSelected(_ item: MediaMetadata) -> Bool {
        selectedMedia.contains(item.id)
    }
    
    func clearSelection() {
        selectedMedia.removeAll()
    }
    
    func selectAllItems() {
        selectedMedia.removeAll()
        lastSelectedMediaId = nil
        for item in filteredItems {
            selectedMedia.insert(item.id)
        }
    }
    
    func handleClickSelection(for item: MediaMetadata, addToSelection: Bool) {
        if addToSelection {
            if let lastId = lastSelectedMediaId {
                let lastIndex = filteredItems.firstIndex { $0.id == lastId }
                let currentIndex = filteredItems.firstIndex { $0.id == item.id }
                
                if let li = lastIndex, let ci = currentIndex {
                    let start = min(li, ci)
                    let end = max(li, ci)
                    for i in start...end {
                        selectedMedia.insert(filteredItems[i].id)
                    }
                }
            } else {
                selectedMedia.insert(item.id)
            }
        } else {
            if selectedMedia.contains(item.id) {
                selectedMedia.remove(item.id)
                if lastSelectedMediaId == item.id {
                    lastSelectedMediaId = nil
                }
            } else {
                selectedMedia.insert(item.id)
            }
        }
        lastSelectedMediaId = item.id
    }
    
    func selectItems(in rect: CGRect, gridItemFrames: [UUID: CGRect]) {
        selectedMedia.removeAll()
        for (id, frame) in gridItemFrames {
            if rect.intersects(frame) {
                selectedMedia.insert(id)
            }
        }
    }
    
    func moveSelectedItems(to targetFolder: FolderNode) async -> Bool {
        guard !selectedMedia.isEmpty else { return false }
        
        var movedCount = 0
        let fm = FileManager.default
        
        for item in filteredItems where selectedMedia.contains(item.id) {
            let targetURL = targetFolder.url.appendingPathComponent(item.url.lastPathComponent)
            let sourceURL = item.url
            
            do {
                if fm.fileExists(atPath: targetURL.path) {
                    try fm.removeItem(at: targetURL)
                }
                try fm.moveItem(at: sourceURL, to: targetURL)
                movedCount += 1
            } catch {
                print("Failed to move \(sourceURL.path): \(error)")
            }
        }
        
        if movedCount > 0 {
            selectedMedia.removeAll()
            await refreshCurrentFolder()
            return true
        }
        return false
    }
}
