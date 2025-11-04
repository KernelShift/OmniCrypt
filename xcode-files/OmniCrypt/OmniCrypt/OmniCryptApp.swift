import SwiftUI
import AppKit

@main
struct OmniCryptApp: App {
    @StateObject private var runner = Runner()
    @StateObject private var openHandler = OpenHandler()

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(runner)
                .environmentObject(openHandler)
                .onAppear {
                    // Wire the delegate AFTER SwiftUI has installed the object
                    appDelegate.openHandler = openHandler
                }
        }
        Settings {
            SettingsView()
        }
    }
}
