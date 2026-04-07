import SwiftUI
import AppKit

@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @AppStorage("autoCheckUpdate") var autoCheckUpdate = true
    
    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var latestVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var downloadURL: String = ""
    
    private let currentVersion = appVersion
    private let repoURL = "https://api.github.com/repos/luuuke2233/Photoview/releases/latest"
    
    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        updateAvailable = false
        
        defer { isChecking = false }
        
        guard let url = URL(string: repoURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                let latest = tag.replacingOccurrences(of: "v", with: "")
                latestVersion = latest
                
                if let body = json["body"] as? String {
                    releaseNotes = body
                }
                
                if let assets = json["assets"] as? [[String: Any]],
                   let firstAsset = assets.first,
                   let browserUrl = firstAsset["browser_download_url"] as? String {
                    downloadURL = browserUrl
                }
                
                if compareVersions(latest, currentVersion) > 0 {
                    updateAvailable = true
                }
            }
        } catch {
            print("Failed to check updates: \(error)")
        }
    }
    
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(parts1.count, parts2.count) {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return 1 }
            if p1 < p2 { return -1 }
        }
        return 0
    }
    
    func openGitHubReleases() {
        if let url = URL(string: "https://github.com/luuuke2233/Photoview/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}