import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case nameAsc = "名称 (A-Z)"
    case nameDesc = "名称 (Z-A)"
    case dateNewest = "日期 (最新)"
    case dateOldest = "日期 (最早)"
    case sizeLargest = "大小 (大→小)"
    case sizeSmallest = "大小 (小→大)"
    
    var id: String { rawValue }
}

enum FilterOption: String, CaseIterable, Identifiable {
    case all = "全部"
    case images = "仅图片"
    case videos = "仅视频"
    
    var id: String { rawValue }
}
