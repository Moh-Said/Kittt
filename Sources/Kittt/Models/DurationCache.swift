import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class DurationCache {
    private var cache: [URL: TimeInterval] = [:]
    @ObservationIgnored private var inFlight: Set<URL> = []

    func duration(for url: URL) -> TimeInterval? {
        cache[url]
    }

    func load(_ url: URL) async {
        guard cache[url] == nil, !inFlight.contains(url) else { return }
        inFlight.insert(url)
        defer { inFlight.remove(url) }

        let asset = AVURLAsset(url: url)
        if let cm = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(cm)
            if seconds.isFinite, seconds > 0 {
                cache[url] = seconds
            }
        }
    }
}
