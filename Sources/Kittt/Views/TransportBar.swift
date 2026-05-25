import SwiftUI

struct TransportBar: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Text(formatTime(player.currentTime))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 0.01)
                )
                .disabled(player.duration <= 0)

                Text(formatTime(player.duration))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 18) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .help("Previous (⌘←)")

                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .help("Play/Pause (Space)")

                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .help("Next (⌘→)")
            }
            .fixedSize()

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { Double(player.volume) },
                        set: { player.volume = Float($0) }
                    ),
                    in: 0...1
                )
                .frame(width: 90)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .fixedSize()

            Button {
                player.miniPlayerMode = true
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Mini player")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
