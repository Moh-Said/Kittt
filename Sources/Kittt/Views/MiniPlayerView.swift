import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerModel.self) private var player
    @State private var hovering = false

    var body: some View {
        @Bindable var player = player

        ZStack(alignment: .topTrailing) {
            background

            VStack(spacing: 4) {
                artwork
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(radius: 4, y: 2)
                    .padding(.top, 2)

                Text(player.currentMetadata.artist ?? " ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 6)

                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                WaveformVisualization(size: CGSize(width: 140, height: 22), barCount: 12)
                    .padding(.vertical, 4)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button { player.toggleMute() } label: {
                        Image(systemName: (player.volume == 0 || player.isMuted) ? "speaker.slash.fill" : "speaker.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(player.isMuted ? "Unmute" : "Mute")

                    Slider(value: $player.volume, in: 0...1)
                        .controlSize(.mini)
                        .frame(width: 180)

                    // an invisible balancer on the trailing side
                    Color.clear
                        .frame(width: 14, height: 14)
                }
                .padding(.bottom, 4)
                .opacity(hovering ? 1 : 0)
                .scaleEffect(hovering ? 1 : 0.85)
                .animation(.easeInOut(duration: 0.15), value: hovering)

                HStack(spacing: 28) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill").font(.title3)
                    }
                    .buttonStyle(.plain)

                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    Text(formatTime(player.currentTime))
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)

                    Slider(
                        value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 0.01)
                    )
                    .disabled(player.duration <= 0)

                    Text(formatTime(player.duration))
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 320, height: 290)
            .animation(.easeInOut(duration: 0.2), value: player.currentTrack?.id)

            Button {
                player.miniPlayerMode = false
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 12)
            .opacity(hovering ? 1 : 0)
            .scaleEffect(hovering ? 1 : 0.85)
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .help("Expand")

        }
        .frame(width: 320, height: 290)
        .onHover { hovering = $0 }
    }

    private var displayTitle: String {
        if let t = player.currentMetadata.title, !t.isEmpty { return t }
        return player.currentTrack?.displayName ?? "Nothing playing"
    }

    @ViewBuilder
    private var artwork: some View {
        if let img = player.currentMetadata.artwork {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if let img = player.currentMetadata.artwork {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 320)
                .blur(radius: 40)
                .opacity(0.32)
                .clipped()
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
