import Foundation
import AppKit

/// Service for fetching album artwork from various sources
actor ArtworkService {
    private var spotifyAccessToken: String?
    private var tokenExpiration: Date?
    private let urlSession: URLSession
    private let discogsService = DiscogsService()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.urlSession = URLSession(configuration: config)
    }

    /// Fetch artwork for a track, trying multiple sources
    func fetchArtwork(for track: Track) async -> NSImage? {
        // Try Spotify Web API first (if credentials configured)
        if Secrets.hasSpotifyCredentials {
            if let image = await fetchFromSpotify(track: track) {
                return image
            }
        }

        // Fallback to iTunes Search API
        if let image = await fetchFromiTunes(track: track) {
            return image
        }

        // Try Discogs
        if let image = await fetchFromDiscogs(track: track) {
            return image
        }

        // Final fallback: MusicBrainz + Cover Art Archive
        if let image = await fetchFromMusicBrainz(track: track) {
            return image
        }

        return nil
    }

    // MARK: - Spotify Web API

    private func fetchFromSpotify(track: Track) async -> NSImage? {
        do {
            let token = try await getSpotifyAccessToken()

            // Search for the track
            let query = "\(track.name) artist:\(track.artist)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

            guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(query)&type=track&limit=1") else {
                return nil
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await urlSession.data(for: request)

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tracks = json["tracks"] as? [String: Any],
                  let items = tracks["items"] as? [[String: Any]],
                  let firstTrack = items.first,
                  let album = firstTrack["album"] as? [String: Any],
                  let images = album["images"] as? [[String: Any]],
                  let imageInfo = images.first,
                  let imageUrl = imageInfo["url"] as? String,
                  let url = URL(string: imageUrl) else {
                return nil
            }

            return await downloadImage(from: url)
        } catch {
            print("Spotify artwork error: \(error)")
            return nil
        }
    }

    private func getSpotifyAccessToken() async throws -> String {
        // Return cached token if still valid
        if let token = spotifyAccessToken,
           let expiration = tokenExpiration,
           Date() < expiration {
            return token
        }

        // Request new token using Client Credentials flow
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(Secrets.spotifyClientId):\(Secrets.spotifyClientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, _) = try await urlSession.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw URLError(.cannotParseResponse)
        }

        self.spotifyAccessToken = token
        self.tokenExpiration = Date().addingTimeInterval(TimeInterval(expiresIn - 60)) // Buffer of 60 seconds

        return token
    }

    // MARK: - iTunes Search API

    private func fetchFromiTunes(track: Track) async -> NSImage? {
        let query = "\(track.name) \(track.artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "https://itunes.apple.com/search?term=\(query)&media=music&limit=1") else {
            print("iTunes: Invalid URL")
            return nil
        }

        print("iTunes: Searching for '\(track.name) \(track.artist)'")

        do {
            let (data, _) = try await urlSession.data(from: url)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first,
                  var artworkUrl = firstResult["artworkUrl100"] as? String else {
                print("iTunes: No results found")
                return nil
            }

            // Get higher resolution image
            artworkUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")

            print("iTunes: Found artwork URL: \(artworkUrl)")

            guard let imageUrl = URL(string: artworkUrl) else {
                return nil
            }

            return await downloadImage(from: imageUrl)
        } catch {
            print("iTunes artwork error: \(error)")
            return nil
        }
    }

    // MARK: - MusicBrainz + Cover Art Archive

    private func fetchFromMusicBrainz(track: Track) async -> NSImage? {
        let query = "\(track.name) AND artist:\(track.artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "https://musicbrainz.org/ws/2/recording?query=\(query)&limit=1&fmt=json") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Overture/1.0 (contact@example.com)", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await urlSession.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let recordings = json["recordings"] as? [[String: Any]],
                  let firstRecording = recordings.first,
                  let releases = firstRecording["releases"] as? [[String: Any]],
                  let firstRelease = releases.first,
                  let releaseId = firstRelease["id"] as? String else {
                return nil
            }

            // Fetch from Cover Art Archive
            guard let coverArtUrl = URL(string: "https://coverartarchive.org/release/\(releaseId)/front-500") else {
                return nil
            }

            return await downloadImage(from: coverArtUrl)
        } catch {
            print("MusicBrainz artwork error: \(error)")
            return nil
        }
    }

    // MARK: - Discogs

    private func fetchFromDiscogs(track: Track) async -> NSImage? {
        print("Discogs: Searching for '\(track.artist) - \(track.album)'")

        guard let images = await discogsService.fetchImages(artist: track.artist, album: track.album),
              let primaryImage = images.primaryImage else {
            print("Discogs: No images found")
            return nil
        }

        print("Discogs: Found primary image")
        return await downloadImage(from: URL(string: primaryImage.uri)!)
    }

    // MARK: - Helpers

    private func downloadImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await urlSession.data(from: url)
            return NSImage(data: data)
        } catch {
            print("Image download error: \(error)")
            return nil
        }
    }
}
