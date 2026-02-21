import Foundation

/// API credentials for external services
///
/// To get Spotify credentials:
/// 1. Go to https://developer.spotify.com/dashboard
/// 2. Create a new app
/// 3. Copy Client ID and Client Secret here
enum Secrets {
    /// Spotify Web API Client ID
    static let spotifyClientId = ""

    /// Spotify Web API Client Secret
    static let spotifyClientSecret = ""

    /// Check if Spotify credentials are configured
    static var hasSpotifyCredentials: Bool {
        !spotifyClientId.isEmpty && !spotifyClientSecret.isEmpty
    }
}
