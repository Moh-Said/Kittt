import SwiftUI

struct NowPlayingPanel: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            artwork
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Text(player.currentMetadata.artist ?? " ")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(player.currentMetadata.album ?? " ")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxHeight: 88, alignment: .center)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("NOW PLAYING")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                WaveformVisualization()
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundLayer)
        .animation(.easeInOut(duration: 0.2), value: player.currentTrack?.id)
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
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let img = player.currentMetadata.artwork {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .blur(radius: 40)
                .opacity(0.30)
                .clipped()
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
