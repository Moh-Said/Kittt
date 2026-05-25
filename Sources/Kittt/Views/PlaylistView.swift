import SwiftUI

struct PlaylistView: View {
    @Environment(PlayerModel.self) private var player
    let sidebarHidden: Bool

    private var displayPlaylist: Playlist? {
        if sidebarHidden, let playing = player.playingPlaylist {
            return playing
        }
        return player.selectedPlaylist
    }

    var body: some View {
        if let pl = displayPlaylist {
            List {
                ForEach(Array(pl.tracks.enumerated()), id: \.element.id) { index, track in
                    row(index: index, track: track, playlistID: pl.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            player.play(trackAt: index, in: pl.id)
                        }
                }
            }
            .listStyle(.inset)
        } else {
            ContentUnavailableView {
                Label("No folder open", systemImage: "folder.badge.plus")
            } description: {
                Text("Pick a music folder, or right-click a folder in Finder and choose Open With ▸ Kittt.")
            } actions: {
                HStack(spacing: 10) {
                    Button {
                        player.openFolderPicker()
                    } label: {
                        Text("Open a folder")
                            .frame(minWidth: 100)
                    }
                    .controlSize(.large)
                    .keyboardShortcut("o", modifiers: .command)

                    Button {
                        player.openFilePicker()
                    } label: {
                        Text("Open a file")
                            .frame(minWidth: 100)
                    }
                    .controlSize(.large)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                }
            }
        }
    }

    @ViewBuilder
    private func row(index: Int, track: Track, playlistID: Playlist.ID) -> some View {
        let isCurrent = player.playingPlaylistID == playlistID && player.currentTrackIndex == index
        HStack(spacing: 10) {
            Group {
                if isCurrent && player.isPlaying {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
                } else if isCurrent {
                    Image(systemName: "pause.fill").foregroundStyle(.secondary)
                } else {
                    Text("\(index + 1)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(width: 28, alignment: .trailing)

            Text(track.displayName)
                .lineLimit(1)
                .fontWeight(isCurrent ? .semibold : .regular)

            Spacer(minLength: 8)

            Text(durationText(for: track))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .task(id: track.id) {
            await player.durationCache.load(track.url)
        }
    }

    private func durationText(for track: Track) -> String {
        if player.currentTrack?.id == track.id, player.duration > 0 {
            return formatTime(player.duration)
        }
        if let dur = player.durationCache.duration(for: track.url) {
            return formatTime(dur)
        }
        return "—"
    }
}
