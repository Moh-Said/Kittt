import Foundation
import Observation
import MediaPlayer
import AppKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class PlayerModel {
    var playlists: [Playlist] = []
    var rootFolderName: String = ""
    var selectedPlaylistID: Playlist.ID?
    var playingPlaylistID: Playlist.ID?

    var currentTrackIndex: Int?
    var currentMetadata: TrackMetadata = TrackMetadata()

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 0.8 {
        didSet { engine.volume = volume }
    }

    var miniPlayerMode: Bool = false

    let durationCache = DurationCache()

    @ObservationIgnored private let engine = AudioEngine()
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var metadataTaskID = UUID()

    var selectedPlaylist: Playlist? {
        guard let id = selectedPlaylistID else { return nil }
        return playlists.first { $0.id == id }
    }

    var playingPlaylist: Playlist? {
        guard let id = playingPlaylistID else { return nil }
        return playlists.first { $0.id == id }
    }

    var currentTrack: Track? {
        guard let pl = playingPlaylist,
              let i = currentTrackIndex,
              pl.tracks.indices.contains(i)
        else { return nil }
        return pl.tracks[i]
    }

    var isSelectedPlaylistPlaying: Bool {
        selectedPlaylistID != nil && selectedPlaylistID == playingPlaylistID
    }

    init() {
        engine.volume = volume
        engine.onFinish = { [weak self] in
            self?.next()
        }
    }

    func loadFolder(_ url: URL) {
        stop()
        playlists = Playlist.discover(at: url)
        rootFolderName = url.lastPathComponent
        selectedPlaylistID = playlists.first?.id
        playingPlaylistID = nil
        currentTrackIndex = nil
    }

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            loadFolder(url)
        }
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Play"
        if panel.runModal() == .OK, let url = panel.url {
            loadSingleFile(url)
        }
    }

    func removePlaylist(_ id: Playlist.ID) {
        if playingPlaylistID == id {
            stop()
        }
        playlists.removeAll { $0.id == id }
        if selectedPlaylistID == id {
            selectedPlaylistID = playlists.first?.id
        }
        if playlists.isEmpty {
            rootFolderName = ""
        }
    }

    func loadSingleFile(_ url: URL) {
        stop()
        let title = url.deletingPathExtension().lastPathComponent
        let playlist = Playlist(
            id: url,
            url: url.deletingLastPathComponent(),
            name: title,
            tracks: [Track(url: url)],
            isRoot: true
        )
        playlists = [playlist]
        rootFolderName = title
        selectedPlaylistID = playlist.id
        play(trackAt: 0, in: playlist.id)
    }

    func playPlaylist(_ id: Playlist.ID) {
        if playingPlaylistID == id, currentTrackIndex != nil, isPlaying {
            if selectedPlaylistID != id { selectedPlaylistID = id }
            return
        }
        if selectedPlaylistID != id { selectedPlaylistID = id }
        play(trackAt: 0, in: id)
    }

    func play(trackAt index: Int, in playlistID: Playlist.ID? = nil) {
        let targetID = playlistID ?? selectedPlaylistID
        guard let pid = targetID,
              let pl = playlists.first(where: { $0.id == pid }),
              pl.tracks.indices.contains(index) else { return }
        playingPlaylistID = pid
        currentTrackIndex = index
        let track = pl.tracks[index]

        currentMetadata = TrackMetadata()
        duration = 0
        currentTime = 0

        engine.load(url: track.url)
        engine.play()
        isPlaying = true
        startTimer()

        let taskID = UUID()
        metadataTaskID = taskID
        Task { [weak self] in
            let meta = await MetadataLoader.load(for: track.url)
            await MainActor.run {
                guard let self = self, self.metadataTaskID == taskID else { return }
                self.currentMetadata = meta
                if let d = meta.duration { self.duration = d }
                self.updateNowPlaying()
            }
        }

        updateNowPlaying()
    }

    func togglePlay() {
        if currentTrack == nil {
            if let pl = selectedPlaylist, !pl.tracks.isEmpty {
                play(trackAt: 0, in: pl.id)
            }
            return
        }
        isPlaying ? pause() : resume()
    }

    func pause() {
        engine.pause()
        isPlaying = false
        tickTimer?.invalidate()
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else {
            if let pl = selectedPlaylist, !pl.tracks.isEmpty { play(trackAt: 0, in: pl.id) }
            return
        }
        engine.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    func stop() {
        engine.stop()
        isPlaying = false
        currentTime = 0
        duration = 0
        tickTimer?.invalidate()
        tickTimer = nil
        currentMetadata = TrackMetadata()
        playingPlaylistID = nil
        currentTrackIndex = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func next() {
        guard let pl = playingPlaylist, let i = currentTrackIndex else { return }
        if pl.tracks.indices.contains(i + 1) {
            play(trackAt: i + 1, in: pl.id)
        } else {
            stop()
        }
    }

    func previous() {
        guard let pl = playingPlaylist, let i = currentTrackIndex else { return }
        if engine.currentTime > 3 {
            seek(to: 0)
            return
        }
        if pl.tracks.indices.contains(i - 1) {
            play(trackAt: i - 1, in: pl.id)
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        currentTime = time
        updateNowPlaying()
    }

    func seekRelative(_ delta: TimeInterval) {
        let target = max(0, min(duration > 0 ? duration : .greatestFiniteMagnitude, currentTime + delta))
        seek(to: target)
    }

    func adjustVolume(_ delta: Float) {
        volume = max(0, min(1, volume + delta))
    }

    private func startTimer() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.currentTime = self.engine.currentTime
                if self.duration == 0, self.engine.duration > 0 {
                    self.duration = self.engine.duration
                }
            }
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentMetadata.title ?? track.displayName,
            MPMediaItemPropertyArtist: currentMetadata.artist ?? "",
            MPMediaItemPropertyAlbumTitle: currentMetadata.album ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let img = currentMetadata.artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
