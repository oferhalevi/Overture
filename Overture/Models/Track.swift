import Foundation

struct Track: Equatable, Identifiable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let duration: TimeInterval
    var position: TimeInterval
    var isPlaying: Bool

    init(name: String, artist: String, album: String, duration: TimeInterval = 0, position: TimeInterval = 0, isPlaying: Bool = false) {
        self.id = "\(name)-\(artist)-\(album)"
        self.name = name
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
    }

    /// Check if this represents the same track (ignoring playback state)
    func isSameTrack(as other: Track?) -> Bool {
        guard let other = other else { return false }
        return name == other.name && artist == other.artist && album == other.album
    }

    /// Search query for finding artwork
    var artworkSearchQuery: String {
        "\(name) \(artist)"
    }

    /// Wikipedia search query for artist
    var artistWikiQuery: String {
        // Add common suffixes for disambiguation
        "\(artist) musician"
    }
}
