import Foundation

struct Track: Identifiable, Hashable {
    let id: URL
    let url: URL

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    init(url: URL) {
        self.id = url
        self.url = url
    }
}
