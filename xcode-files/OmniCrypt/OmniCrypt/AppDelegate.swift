import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var openHandler: OpenHandler?

    func application(_ application: NSApplication, open urls: [URL]) {
        openHandler?.enqueue(urls: urls)
    }
}
