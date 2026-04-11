import Foundation

enum ViewMode: String, CaseIterable, Codable, Identifiable {
    case grid = "grid"
    case list = "list"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
    
    var title: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        }
    }
}

enum ToolbarItemType: String, CaseIterable, Codable, Identifiable {
    case refresh = "refresh"
    case addFolder = "addFolder"
    case selectAll = "selectAll"
    case deselect = "deselect"
    case filter = "filter"
    case sort = "sort"
    case viewMode = "viewMode"
    case folderInfo = "folderInfo"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .refresh: return "arrow.clockwise"
        case .addFolder: return "folder.badge.plus"
        case .selectAll: return "checkmark.circle"
        case .deselect: return "circle"
        case .filter: return "line.3.horizontal.decrease.circle"
        case .sort: return "arrow.up.arrow.down"
        case .viewMode: return "square.grid.2x2"
        case .folderInfo: return "info.circle"
        }
    }
    
    var titleKey: String {
        rawValue
    }
    
    var isBuiltIn: Bool {
        switch self {
        case .refresh, .addFolder, .selectAll, .deselect, .filter, .sort, .folderInfo: return true
        case .viewMode: return false
        }
    }
}

struct ToolbarItem: Identifiable, Codable, Equatable {
    let id: String
    let type: ToolbarItemType
    var isEnabled: Bool
    
    init(type: ToolbarItemType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.isEnabled = isEnabled
    }
}

@MainActor
class ToolbarManager: ObservableObject {
    static let shared = ToolbarManager()
    
    private let userDefaultsKey = "toolbarItems"
    private let viewModeKey = "viewMode"
    
    @Published var items: [ToolbarItem] = [] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    @Published var isCustomizing: Bool = false
    
    @Published var currentViewMode: ViewMode = .grid {
        didSet {
            UserDefaults.standard.set(currentViewMode.rawValue, forKey: viewModeKey)
        }
    }
    
    private init() {
        loadFromUserDefaults()
        if items.isEmpty {
            items = ToolbarItemType.allCases.filter { $0.isBuiltIn }.map { ToolbarItem(type: $0) }
        }
        if let modeRaw = UserDefaults.standard.string(forKey: viewModeKey),
           let mode = ViewMode(rawValue: modeRaw) {
            currentViewMode = mode
        }
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ToolbarItem].self, from: data) {
            items = decoded
        }
    }
    
    func addItem(_ type: ToolbarItemType) {
        guard !items.contains(where: { $0.type == type }) else { return }
        items.append(ToolbarItem(type: type))
    }
    
    func removeItem(_ item: ToolbarItem) {
        items.removeAll { $0.id == item.id }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
    
    func resetToDefault() {
        items = ToolbarItemType.allCases.filter { $0.isBuiltIn }.map { ToolbarItem(type: $0) }
    }
}