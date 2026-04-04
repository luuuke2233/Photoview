import SwiftUI

@main
struct PhotoViewApp: App {
    @StateObject private var library = LibraryManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(library)
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
        }
    }
}
