import SwiftUI

enum AppLanguage: String, CaseIterable {
    case system = "跟随系统"
    case chinese = "中文"
    case english = "English"
    
    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        case .chinese:
            return Locale(identifier: "zh_CN")
        case .english:
            return Locale(identifier: "en_US")
        }
    }
}

@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var _trigger: Int = 0
    
    @AppStorage("selectedLanguage") var currentLanguageRaw: String = AppLanguage.system.rawValue {
        didSet {
            _trigger += 1
        }
    }
    
    var currentLanguage: AppLanguage {
        get { AppLanguage(rawValue: currentLanguageRaw) ?? .system }
        set { currentLanguageRaw = newValue.rawValue }
    }
    
    var locale: Locale {
        currentLanguage.locale
    }
    
    func tr(_ zh: String, _ en: String) -> String {
        _ = _trigger
        return currentLanguage == .english ? en : zh
    }
    
    func sortName(_ option: SortOption) -> String {
        _ = _trigger
        switch option {
        case .nameAsc: return currentLanguage == .english ? "Name (A-Z)" : "名称 (A-Z)"
        case .nameDesc: return currentLanguage == .english ? "Name (Z-A)" : "名称 (Z-A)"
        case .dateNewest: return currentLanguage == .english ? "Date (Newest)" : "日期 (最新)"
        case .dateOldest: return currentLanguage == .english ? "Date (Oldest)" : "日期 (最早)"
        case .sizeLargest: return currentLanguage == .english ? "Size (Largest)" : "大小 (大→小)"
        case .sizeSmallest: return currentLanguage == .english ? "Size (Smallest)" : "大小 (小→大)"
        }
    }
    
    func filterName(_ option: FilterOption) -> String {
        _ = _trigger
        switch option {
        case .all: return currentLanguage == .english ? "All" : "全部"
        case .images: return currentLanguage == .english ? "Images Only" : "仅图片"
        case .videos: return currentLanguage == .english ? "Videos Only" : "仅视频"
        }
    }
}

struct LocalizedString {
    static let interface = "界面"
    static let language = "语言"
    static let theme = "主题"
    static let cache = "缓存"
    static let thumbnailCacheCount = "缩略图缓存数量"
    static let clearCache = "清除缓存"
    static let performance = "性能"
    static let general = "通用"
    static let emptyFolder = "空文件夹"
    static let addFolder = "添加文件夹"
    static let filter = "筛选"
    static let sort = "排序"
    static let refresh = "刷新"
    static let selectAll = "全选"
    static let deselect = "取消选择"
    static let scanning = "扫描中..."
    static let noMedia = "无媒体"
    static let noMediaDescription = "添加文件夹或切换筛选条件"
    static let showInFinder = "在 Finder 中显示"
    static let exitFullscreen = "退出全屏并关闭窗口"
    static let resetZoom = "重置缩放"
    static let rotateLeft = "向左旋转90度"
    static let rotateRight = "向右旋转90度"
    static let resetView = "重置画面"
    static let version = "版本"
    static let update = "更新"
    static let currentVersion = "当前版本"
    static let autoCheckUpdate = "自动检测更新"
    static let checkForUpdates = "检测更新"
    static let updateAvailable = "发现新版本"
    static let viewOnGitHub = "在 GitHub 查看"
    static let upToDate = "已是最新版本"
}

struct LocalizedString_en {
    static let interface = "Interface"
    static let language = "Language"
    static let theme = "Theme"
    static let cache = "Cache"
    static let thumbnailCacheCount = "Thumbnail Cache Count"
    static let clearCache = "Clear Cache"
    static let performance = "Performance"
    static let general = "General"
    static let emptyFolder = "Empty Folder"
    static let addFolder = "Add Folder"
    static let filter = "Filter"
    static let sort = "Sort"
    static let refresh = "Refresh"
    static let selectAll = "Select All"
    static let deselect = "Deselect"
    static let scanning = "Scanning..."
    static let noMedia = "No Media"
    static let noMediaDescription = "Add a folder or change the filter"
    static let showInFinder = "Show in Finder"
    static let exitFullscreen = "Exit fullscreen"
    static let resetZoom = "Reset Zoom"
    static let rotateLeft = "Rotate Left 90°"
    static let rotateRight = "Rotate Right 90°"
    static let resetView = "Reset View"
    static let version = "Version"
    static let update = "Update"
    static let currentVersion = "Current Version"
    static let autoCheckUpdate = "Auto Check for Updates"
    static let checkForUpdates = "Check for Updates"
    static let updateAvailable = "Update Available"
    static let viewOnGitHub = "View on GitHub"
    static let upToDate = "Up to Date"
}
