import Foundation

struct Playlist: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let tracks: [Track]
    let isRoot: Bool

    static let supportedExtensions: Set<String> = [
        "mp3", "flac", "m4a", "aac", "wav", "aif", "aiff", "alac"
    ]

    static func discover(at root: URL) -> [Playlist] {
        let fm = FileManager.default
        let rootContents = (try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var result: [Playlist] = []

        let rootFiles = rootContents.filter { !isDirectory($0) && isAudio($0) }
        if !rootFiles.isEmpty {
            result.append(Playlist(
                id: root,
                url: root,
                name: "\(root.lastPathComponent) (root)",
                tracks: rootFiles.sorted(by: naturalSort).map(Track.init),
                isRoot: true
            ))
        }

        let subdirs = rootContents
            .filter(isDirectory)
            .sorted(by: naturalSort)

        for dir in subdirs {
            let files = collectAudio(in: dir)
            if !files.isEmpty {
                result.append(Playlist(
                    id: dir,
                    url: dir,
                    name: dir.lastPathComponent,
                    tracks: files.map(Track.init),
                    isRoot: false
                ))
            }
        }

        return result
    }

    private static func collectAudio(in dir: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator where isAudio(url) {
            urls.append(url)
        }
        return urls.sorted(by: naturalSort)
    }

    private static func isAudio(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private static func naturalSort(_ a: URL, _ b: URL) -> Bool {
        a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
    }
}
