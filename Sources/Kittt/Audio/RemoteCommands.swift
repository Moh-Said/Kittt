import MediaPlayer

enum RemoteCommands {
    @MainActor
    static func install(player: PlayerModel) {
        let c = MPRemoteCommandCenter.shared()

        c.playCommand.isEnabled = true
        c.pauseCommand.isEnabled = true
        c.togglePlayPauseCommand.isEnabled = true
        c.nextTrackCommand.isEnabled = true
        c.previousTrackCommand.isEnabled = true
        c.changePlaybackPositionCommand.isEnabled = true

        c.playCommand.addTarget { _ in
            Task { @MainActor in player.resume() }
            return .success
        }
        c.pauseCommand.addTarget { _ in
            Task { @MainActor in player.pause() }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in player.togglePlay() }
            return .success
        }
        c.nextTrackCommand.addTarget { _ in
            Task { @MainActor in player.next() }
            return .success
        }
        c.previousTrackCommand.addTarget { _ in
            Task { @MainActor in player.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let t = e.positionTime
            Task { @MainActor in player.seek(to: t) }
            return .success
        }
    }
}
