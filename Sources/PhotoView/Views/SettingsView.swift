import SwiftUI

struct SettingsView: View {
    @AppStorage("cacheSize") private var cacheSize = 500
    @AppStorage("thumbnailQuality") private var quality = 0.85
    @ObservedObject private var appearance = AppearanceManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text(localization.tr(LocalizedString.general, LocalizedString_en.general)).tag(0)
                Text(localization.tr(LocalizedString.performance, LocalizedString_en.performance)).tag(1)
                Text(localization.tr(LocalizedString.update, LocalizedString_en.update)).tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Group {
                switch selectedTab {
                case 0: GeneralSettings()
                case 1: PerformanceSettings()
                case 2: UpdateSettings()
                default: GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 450, height: 280)
    }
}

struct GeneralSettings: View {
    @AppStorage("showToolbarByDefault") private var showToolbarByDefault = false
    @ObservedObject private var appearance = AppearanceManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.tr(LocalizedString.interface, LocalizedString_en.interface))
                .font(.headline)
            
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
            
            Toggle("默认显示独立窗口工具栏", isOn: $showToolbarByDefault)
            
            HStack {
                Text(localization.tr(LocalizedString.version, LocalizedString_en.version))
                Spacer()
                Text("v\(appVersion)")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PerformanceSettings: View {
    @AppStorage("cacheSize") private var cacheSize = 500
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.tr(LocalizedString.cache, LocalizedString_en.cache))
                .font(.headline)
            
            HStack {
                Text(localization.tr(LocalizedString.thumbnailCacheCount, LocalizedString_en.thumbnailCacheCount))
                Spacer()
                Stepper("", value: $cacheSize, in: 100...2000, step: 100)
                Text("\(cacheSize)")
                    .frame(width: 40)
            }
            
            Button(localization.tr(LocalizedString.clearCache, LocalizedString_en.clearCache)) {
                let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("PhotoView")
                try? FileManager.default.removeItem(at: cacheDir)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct UpdateSettings: View {
    @ObservedObject private var updateManager = UpdateManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localization.tr(LocalizedString.currentVersion, LocalizedString_en.currentVersion))
                Spacer()
                Text("v\(appVersion)")
                    .foregroundColor(.secondary)
            }
            
            Toggle(localization.tr(LocalizedString.autoCheckUpdate, LocalizedString_en.autoCheckUpdate), isOn: $updateManager.autoCheckUpdate)
            
            Button(action: {
                Task { await updateManager.checkForUpdates() }
            }) {
                HStack {
                    if updateManager.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(localization.tr(LocalizedString.checkForUpdates, LocalizedString_en.checkForUpdates))
                }
            }
            .disabled(updateManager.isChecking)
            
            if updateManager.updateAvailable {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                    Text(localization.tr(LocalizedString.updateAvailable, LocalizedString_en.updateAvailable))
                        .foregroundColor(.green)
                    Spacer()
                    Button(localization.tr(LocalizedString.viewOnGitHub, LocalizedString_en.viewOnGitHub)) {
                        updateManager.openGitHubReleases()
                    }
                }
            }
            
            if !updateManager.latestVersion.isEmpty && !updateManager.updateAvailable {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                    Text(localization.tr(LocalizedString.upToDate, LocalizedString_en.upToDate))
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}