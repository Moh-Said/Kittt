import AVFoundation

@MainActor
final class AudioEngine {
    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?
    private var storedVolume: Float = 0.8

    var levelTap: AudioLevelTap?
    var onFinish: (() -> Void)?

    var currentTime: TimeInterval {
        let t = CMTimeGetSeconds(player.currentTime())
        return t.isFinite ? max(0, t) : 0
    }

    var duration: TimeInterval {
        guard let item = player.currentItem else { return 0 }
        let d = item.duration
        guard d.isValid, !d.isIndefinite else { return 0 }
        let s = CMTimeGetSeconds(d)
        return s.isFinite ? s : 0
    }

    var volume: Float {
        get { player.volume }
        set {
            storedVolume = newValue
            player.volume = newValue
        }
    }

    func load(url: URL) {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        let item = AVPlayerItem(url: url)
        levelTap?.attach(to: item)
        player.replaceCurrentItem(with: item)
        player.volume = storedVolume
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onFinish?()
            }
        }
    }

    func play() { player.play() }
    func pause() { player.pause() }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        levelTap?.detach()
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }

    func seek(to time: TimeInterval) {
        let t = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
