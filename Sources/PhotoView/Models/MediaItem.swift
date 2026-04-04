import Foundation
import UniformTypeIdentifiers

enum MediaType: String, CaseIterable {
    case image, video
    
    static let supportedImageTypes: Set<UTType> = [
        .jpeg, .png, .gif, .tiff, .heic, .heif,
        UTType(filenameExtension: "webp")!, UTType(filenameExtension: "avif")!
    ]
    
    static let supportedVideoTypes: Set<UTType> = [
        .mpeg4Movie, .quickTimeMovie,
        UTType(filenameExtension: "mov")!, UTType(filenameExtension: "mp4")!,
        UTType(filenameExtension: "mkv")!, UTType(filenameExtension: "webm")!
    ]
    
    static func detectType(for url: URL) -> MediaType? {
        let ext = url.pathExtension.lowercased()
        
        // 核心优化：增加对 webm 的显式支持，防止 UTType 识别失败
        if ext == "webm" { return .video }
        
        if let uti = UTType(filenameExtension: ext) {
            if supportedImageTypes.contains(uti) { return .image }
            if supportedVideoTypes.contains(uti) { return .video }
        }
        return nil
    }
}

struct MediaItem: Identifiable, Equatable, Hashable {
    // 核心修复：使用 URL 作为 ID，确保相同文件在不同实例中 ID 一致
    var id: URL { url }
    
    let url: URL
    let type: MediaType
    let name: String
    let creationDate: Date
    let modificationDate: Date
    let fileSize: Int64
    
    init(url: URL) {
        self.url = url
        self.type = MediaType.detectType(for: url)!
        self.name = url.lastPathComponent
        
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.creationDate = (attrs?[.creationDate] as? Date) ?? Date.distantPast
        self.modificationDate = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
        self.fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }
}