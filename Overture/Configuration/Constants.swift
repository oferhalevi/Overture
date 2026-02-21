import Foundation

enum Constants {
    enum Timing {
        /// How often to poll Spotify for track changes (seconds)
        static let spotifyPollInterval: TimeInterval = 1.0

        /// How long to display each fact before rotating (seconds)
        static let factRotationInterval: TimeInterval = 8.0

        /// Fade transition duration for facts (seconds)
        static let factFadeDuration: Double = 0.5

        /// Color transition duration (seconds)
        static let colorTransitionDuration: Double = 1.0

        /// Wikipedia rate limit (seconds between requests)
        static let wikipediaRateLimit: TimeInterval = 1.0
    }

    enum Cache {
        /// How long to cache facts for a track (seconds)
        static let factsCacheDuration: TimeInterval = 3600 // 1 hour
    }

    enum Facts {
        /// Minimum character length for a fact
        static let minLength = 40

        /// Maximum character length for a fact
        static let maxLength = 300

        /// Maximum facts to display per track
        static let maxFactsPerTrack = 10
    }

    enum UI {
        /// Album art size as fraction of window width
        static let albumArtSizeRatio: CGFloat = 0.4

        /// Maximum album art size
        static let maxAlbumArtSize: CGFloat = 400

        /// Minimum album art size
        static let minAlbumArtSize: CGFloat = 200

        /// Corner radius for album art
        static let albumArtCornerRadius: CGFloat = 12

        /// Shadow radius for album art
        static let albumArtShadowRadius: CGFloat = 30
    }

    enum ColorExtraction {
        /// Size to resize images for color extraction
        static let sampleSize = 100

        /// Number of dominant colors to extract
        static let colorCount = 5

        /// Minimum difference between colors (0-1)
        static let colorDifferenceThreshold: CGFloat = 0.1
    }
}
