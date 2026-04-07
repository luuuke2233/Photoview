import SwiftUI

@main
struct PhotoViewApp: App {
    @StateObject private var library = LibraryManager.shared
    @ObservedObject private var appearance = AppearanceManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .preferredColorScheme(appearance.colorScheme)
                .environment(\.locale, localization.locale)
                .onAppear {
                    if updateManager.autoCheckUpdate {
                        Task { await updateManager.checkForUpdates() }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
        }
    }
}
