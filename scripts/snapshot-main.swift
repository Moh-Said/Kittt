import SwiftUI
import AppKit

@main
struct SnapshotMain {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let player = makePlayer()

        renderView(
            MiniPlayerView().environment(player),
            size: CGSize(width: 320, height: 320),
            name: "mini-player.png"
        )

        renderView(
            NowPlayingPanel()
                .environment(player)
                .background(Color(nsColor: .windowBackgroundColor)),
            size: CGSize(width: 720, height: 130),
            name: "now-playing-panel.png"
        )

        renderView(
            TransportBar()
                .environment(player)
                .background(Color(nsColor: .windowBackgroundColor)),
            size: CGSize(width: 720, height: 60),
            name: "transport-bar.png"
        )

        renderView(
            SidebarView()
                .environment(player)
                .background(Color(nsColor: .windowBackgroundColor)),
            size: CGSize(width: 240, height: 320),
            name: "sidebar.png"
        )
    }

    @MainActor
    static func makePlayer() -> PlayerModel {
        let p = PlayerModel()
        p.currentMetadata = TrackMetadata(
            title: "In Da Club",
            artist: "50 Cent",
            album: "Get Rich Or Die Tryin'",
            duration: 213,
            artwork: makeFakeArtwork()
        )
        let folder = URL(fileURLWithPath: "/tmp/Get Rich Or Die Tryin'")
        let tracks = (1...5).map { i in
            Track(url: folder.appendingPathComponent("0\(i). Track \(i).flac"))
        }
        let pl = Playlist(id: folder, url: folder,
                          name: "Get Rich Or Die Tryin'",
                          tracks: tracks,
                          isRoot: false)
        let pl2 = Playlist(id: URL(fileURLWithPath: "/tmp/Albums/Other"),
                           url: URL(fileURLWithPath: "/tmp/Albums/Other"),
                           name: "Snoop Dogg - No Limit",
                           tracks: tracks,
                           isRoot: false)
        p.playlists = [pl, pl2]
        p.rootFolderName = "Musique"
        p.selectedPlaylistID = pl.id
        p.playingPlaylistID = pl.id
        p.currentTrackIndex = 0
        p.isPlaying = true
        p.currentTime = 25
        p.duration = 213
        p.volume = 0.7
        return p
    }

    @MainActor
    static func makeFakeArtwork() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let image = NSImage(size: size)
        image.lockFocus()
        let gradient = NSGradient(colors: [
            NSColor(red: 0.75, green: 0.10, blue: 0.10, alpha: 1),
            NSColor(red: 0.20, green: 0.02, blue: 0.02, alpha: 1)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 56, weight: .heavy),
            .foregroundColor: NSColor.white
        ]
        let title = "50 CENT"
        let s = NSAttributedString(string: title, attributes: attrs)
        let bounds = s.boundingRect(with: size, options: [.usesLineFragmentOrigin])
        let origin = NSPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2)
        s.draw(at: origin)
        image.unlockFocus()
        return image
    }

    @MainActor
    static func renderView<V: View>(_ view: V, size: CGSize, name: String) {
        let wrapped = AnyView(
            view
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)
        )

        let hosting = NSHostingView(rootView: wrapped)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.appearance = NSAppearance(named: .darkAqua)

        // Embed in a borderless window — needed for AppKit-backed views
        // (NSSlider via NSViewRepresentable) to lay out and draw correctly.
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        // Let SwiftUI complete one layout pass.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            FileHandle.standardError.write(Data("snapshot: no bitmap rep for \(name)\n".utf8))
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: PNG encode failed for \(name)\n".utf8))
            return
        }
        let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build/snapshots")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outPath = outDir.appendingPathComponent(name)
        do {
            try png.write(to: outPath)
            print("snapshot: \(outPath.path)")
        } catch {
            FileHandle.standardError.write(Data("snapshot: write failed: \(error)\n".utf8))
        }
    }
}
