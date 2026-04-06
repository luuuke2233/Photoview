import SwiftUI

struct SettingsView: View {
    @AppStorage("cacheSize") private var cacheSize = 500
    @AppStorage("thumbnailQuality") private var quality = 0.85
    @ObservedObject private var appearance = AppearanceManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(localization.tr(LocalizedString.general, LocalizedString_en.general), systemImage: "gear") }
            PerformanceSettings()
                .tabItem { Label(localization.tr(LocalizedString.performance, LocalizedString_en.performance), systemImage: "speedometer") }
        }.frame(width: 450, height: 250)
    }
}

struct GeneralSettings: View {
    @ObservedObject private var appearance = AppearanceManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        Form {
            Section(localization.tr(LocalizedString.interface, LocalizedString_en.interface)) {
                HStack {
                    Text("语言 Language")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { localization.currentLanguage },
                        set: { localization.currentLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                
                HStack {
                    Text(localization.tr(LocalizedString.theme, LocalizedString_en.theme))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { appearance.currentTheme },
                        set: { appearance.currentTheme = $0 }
                    )) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName(localization)).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }
        }.padding()
    }
}

struct PerformanceSettings: View {
    @AppStorage("cacheSize") private var cacheSize = 500
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        Form {
            Section(localization.tr(LocalizedString.cache, LocalizedString_en.cache)) {
                Stepper("\(localization.tr(LocalizedString.thumbnailCacheCount, LocalizedString_en.thumbnailCacheCount)): \(cacheSize)", value: $cacheSize, in: 100...2000, step: 100)
                Button(localization.tr(LocalizedString.clearCache, LocalizedString_en.clearCache)) {
                    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("PhotoView")
                    try? FileManager.default.removeItem(at: cacheDir)
                }
            }
        }.padding()
    }
}
