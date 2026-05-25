import AVFoundation
import AppKit

struct TrackMetadata: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval?
    var artwork: NSImage?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.duration == rhs.duration
            && (lhs.artwork === rhs.artwork)
    }
}

enum MetadataLoader {
    static func load(for url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        var meta = TrackMetadata()

        if let items = try? await asset.load(.commonMetadata) {
            await apply(items: items, to: &meta, treatingAsCommon: true)
        }

        if needsFallback(meta), let formats = try? await asset.load(.availableMetadataFormats) {
            for fmt in formats {
                if let items = try? await asset.loadMetadata(for: fmt) {
                    await apply(items: items, to: &meta, treatingAsCommon: false)
                }
                if !needsFallback(meta) { break }
            }
        }

        if meta.artwork == nil {
            meta.artwork = findSidecarArtwork(near: url)
        }

        if let d = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(d)
            if seconds.isFinite, seconds > 0 { meta.duration = seconds }
        }

        return meta
    }

    private static func needsFallback(_ m: TrackMetadata) -> Bool {
        m.title == nil || m.artist == nil || m.album == nil || m.artwork == nil
    }

    private static func apply(items: [AVMetadataItem], to meta: inout TrackMetadata, treatingAsCommon: Bool) async {
        for item in items {
            if treatingAsCommon, let key = item.commonKey {
                switch key {
                case .commonKeyTitle:
                    if meta.title == nil, let s = try? await item.load(.stringValue) { meta.title = s }
                case .commonKeyArtist:
                    if meta.artist == nil, let s = try? await item.load(.stringValue) { meta.artist = s }
                case .commonKeyAlbumName:
                    if meta.album == nil, let s = try? await item.load(.stringValue) { meta.album = s }
                case .commonKeyArtwork:
                    if meta.artwork == nil,
                       let data = try? await item.load(.dataValue),
                       let img = imageFromArtworkData(data) {
                        meta.artwork = img
                    }
                default:
                    break
                }
                continue
            }

            let keyName = (item.key as? String)?.uppercased() ?? ""
            let identifier = item.identifier?.rawValue ?? ""

            switch keyName {
            case "TITLE", "©NAM":
                if meta.title == nil, let s = try? await item.load(.stringValue) { meta.title = s }
            case "ARTIST", "ALBUMARTIST", "ALBUM ARTIST", "©ART", "AART":
                if meta.artist == nil, let s = try? await item.load(.stringValue), !s.isEmpty { meta.artist = s }
            case "ALBUM", "©ALB":
                if meta.album == nil, let s = try? await item.load(.stringValue) { meta.album = s }
            case "METADATA_BLOCK_PICTURE", "COVERART", "COVER ART (FRONT)", "PICTURE", "COVR":
                if meta.artwork == nil,
                   let data = try? await item.load(.dataValue),
                   let img = imageFromArtworkData(data) {
                    meta.artwork = img
                }
            default:
                if meta.artwork == nil,
                   identifier.lowercased().contains("picture") || identifier.lowercased().contains("artwork") || identifier.lowercased().contains("covr"),
                   let data = try? await item.load(.dataValue),
                   let img = imageFromArtworkData(data) {
                    meta.artwork = img
                }
            }
        }
    }

    private static func imageFromArtworkData(_ data: Data) -> NSImage? {
        if let img = NSImage(data: data), img.isValid, img.size.width > 0 {
            return img
        }
        if let inner = unwrapFlacPictureBlock(data), let img = NSImage(data: inner) {
            return img
        }
        return nil
    }

    private static func unwrapFlacPictureBlock(_ data: Data) -> Data? {
        guard data.count > 32 else { return nil }
        var offset = 4
        guard let mimeLen = readUInt32BE(data, at: offset) else { return nil }
        offset += 4
        offset += Int(mimeLen)
        guard offset + 4 <= data.count, let descLen = readUInt32BE(data, at: offset) else { return nil }
        offset += 4
        offset += Int(descLen)
        offset += 16
        guard offset + 4 <= data.count, let picLen = readUInt32BE(data, at: offset) else { return nil }
        offset += 4
        guard offset + Int(picLen) <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + Int(picLen)))
    }

    private static func readUInt32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let bytes = data[offset..<(offset + 4)]
        var v: UInt32 = 0
        for b in bytes { v = (v << 8) | UInt32(b) }
        return v
    }

    private static let sidecarNames = [
        "cover.jpg", "cover.jpeg", "cover.png",
        "folder.jpg", "folder.jpeg", "folder.png",
        "front.jpg", "front.jpeg", "front.png",
        "albumart.jpg", "albumart.jpeg", "albumart.png",
        "album.jpg", "album.png"
    ]

    private static func findSidecarArtwork(near trackURL: URL) -> NSImage? {
        let dir = trackURL.deletingLastPathComponent()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        let lowerMap: [String: URL] = Dictionary(uniqueKeysWithValues: entries.map { ($0.lastPathComponent.lowercased(), $0) })
        for name in sidecarNames {
            if let url = lowerMap[name], let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }
}
