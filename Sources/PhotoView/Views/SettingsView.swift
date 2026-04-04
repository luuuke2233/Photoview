import SwiftUI

struct SettingsView: View {
    @AppStorage("cacheSize") private var cacheSize = 500
    @AppStorage("thumbnailQuality") private var quality = 0.85
    
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("通用", systemImage: "gear") }
            PerformanceSettings()
                .tabItem { Label("性能", systemImage: "speedometer") }
        }.frame(width: 450, height: 250)
    }
}

struct GeneralSettings: View {
    var body: some View {
        Form {
            Section("界面") {
                Toggle("显示文件扩展名", isOn: .constant(false))
                Toggle("启动时自动扫描", isOn: .constant(true))
            }
            Section("预留功能") {
                Button("同步到云端 (预留)") { }
                Button("导出元数据 (预留)") { }
            }
        }.padding()
    }
}

struct PerformanceSettings: View {
    @AppStorage("cacheSize") private var cacheSize = 500
    var body: some View {
        Form {
            Section("缓存") {
                Stepper("缩略图缓存数量: \(cacheSize)", value: $cacheSize, in: 100...2000, step: 100)
                Button("清除缓存") {
                    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("PhotoView")
                    try? FileManager.default.removeItem(at: cacheDir)
                }
            }
        }.padding()
    }
}
