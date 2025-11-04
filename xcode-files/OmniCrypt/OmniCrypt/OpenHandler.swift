import Foundation

final class OpenHandler: ObservableObject {
    @Published var pendingPaths: [String] = []

    func enqueue(urls: [URL]) {
        let paths = urls.map { $0.path }
        DispatchQueue.main.async {
            self.pendingPaths.append(contentsOf: paths)
        }
    }
}
