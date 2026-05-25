import SwiftUI
import AppKit

private struct RowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct SidebarView: View {
    @Environment(PlayerModel.self) private var player
    @State private var hoveredID: Playlist.ID?
    @State private var armedForDeletion: Playlist.ID?
    @State private var rowFrames: [URL: CGRect] = [:]
    @State private var rightClickMonitor: Any?

    var body: some View {
        @Bindable var player = player

        List(selection: $player.selectedPlaylistID) {
            if player.playlists.isEmpty {
                Text(player.rootFolderName.isEmpty ? "No folder open" : "No audio in this folder")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(player.playlists) { pl in
                    rowView(for: pl)
                        .tag(Optional(pl.id))
                        .contentShape(Rectangle())
                        .background(GeometryReader { geo in
                            Color.clear.preference(
                                key: RowFramePreferenceKey.self,
                                value: [pl.id: geo.frame(in: .global)]
                            )
                        })
                        .onHover { hovering in
                            if hovering {
                                hoveredID = pl.id
                            } else if hoveredID == pl.id {
                                hoveredID = nil
                            }
                        }
                }
            }
        }
        .onPreferenceChange(RowFramePreferenceKey.self) { frames in
            rowFrames = frames
        }
        .onChange(of: player.selectedPlaylistID) { _, _ in
            armedForDeletion = nil
        }
        .onAppear { installMonitor() }
        .onDisappear { removeMonitor() }
    }

    @ViewBuilder
    private func rowView(for pl: Playlist) -> some View {
        HStack(spacing: 8) {
            Image(systemName: pl.isRoot ? "folder" : "music.note.list")
                .foregroundStyle(.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(pl.name).lineLimit(1)
                Text("\(pl.tracks.count) track\(pl.tracks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            rightAccessory(for: pl)
        }
    }

    @ViewBuilder
    private func rightAccessory(for pl: Playlist) -> some View {
        if armedForDeletion == pl.id {
            Button {
                player.removePlaylist(pl.id)
                armedForDeletion = nil
            } label: {
                Image(systemName: "trash.fill")
                    .font(.body)
                    .foregroundStyle(Color.red)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove from list")
        } else if player.playingPlaylistID == pl.id {
            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 26, height: 26)
        } else if hoveredID == pl.id {
            Button {
                player.playPlaylist(pl.id)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Play \(pl.name)")
        } else {
            Color.clear.frame(width: 26, height: 26)
        }
    }

    private func installMonitor() {
        if rightClickMonitor != nil { return }
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            handleRightClick(event)
            return event
        }
    }

    private func removeMonitor() {
        if let m = rightClickMonitor {
            NSEvent.removeMonitor(m)
            rightClickMonitor = nil
        }
    }

    private func handleRightClick(_ event: NSEvent) {
        guard let contentView = event.window?.contentView else { return }
        let point = contentView.convert(event.locationInWindow, from: nil)
        for (id, frame) in rowFrames {
            if frame.contains(point) {
                armedForDeletion = id
                return
            }
        }
        armedForDeletion = nil
    }
}
