import SwiftUI

struct WaveformVisualization: View {
    @Environment(PlayerModel.self) private var player

    var size: CGSize = CGSize(width: 150, height: 56)
    var barCount: Int = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let amp = max(0.04, CGFloat(player.audioLevel.level))
                drawBars(in: ctx, size: size, t: t, amp: amp)
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(player.isPlaying ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.4), value: player.isPlaying)
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize, t: TimeInterval, amp: CGFloat) {
        let gap: CGFloat = 2
        let totalGap = CGFloat(barCount - 1) * gap
        let barWidth = max(1, (size.width - totalGap) / CGFloat(barCount))

        let gradient = Gradient(stops: [
            .init(color: .accentColor,                              location: 0.0),
            .init(color: .accentColor,                              location: 0.30),
            .init(color: Color(red: 1.00, green: 0.78, blue: 0.30), location: 0.65),
            .init(color: Color(red: 1.00, green: 0.40, blue: 0.32), location: 1.0)
        ])
        let gStart = CGPoint(x: 0, y: size.height)
        let gEnd   = CGPoint(x: 0, y: 0)

        for i in 0..<barCount {
            let phase = sin(t * 3.5 + Double(i) * 0.55)
            let envelope = 0.5 + 0.5 * (0.5 + 0.5 * CGFloat(phase))
            let h = max(2, min(size.height, size.height * amp * envelope * 1.6))
            let x = CGFloat(i) * (barWidth + gap)
            let rect = CGRect(x: x, y: size.height - h, width: barWidth, height: h)
            ctx.fill(
                Path(roundedRect: rect,
                     cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)),
                with: .linearGradient(gradient, startPoint: gStart, endPoint: gEnd)
            )
        }
    }
}
