import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case nameAsc
    case nameDesc
    case dateNewest
    case dateOldest
    case sizeLargest
    case sizeSmallest
    
    var id: String { rawValue }
}

enum FilterOption: String, CaseIterable, Identifiable {
    case all
    case images
    case videos
    
    var id: String { rawValue }
}
