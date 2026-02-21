import Foundation
import AppKit

/// Service for fetching album artwork and vinyl label images from Discogs
/// No authentication required - just needs User-Agent header
/// Rate limit: 25 requests/minute without auth
actor DiscogsService {
    private let urlSession: URLSession
    private let userAgent = "Overture/1.0 (macOS music companion)"

    // Cache to avoid repeated lookups
    private var masterIdCache: [String: Int] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetch all available images for a release (album cover, vinyl labels, back cover, etc.)
    func fetchImages(artist: String, album: String) async -> DiscogsImages? {
        // First search for the master release
        guard let masterId = await searchForMaster(artist: artist, album: album) else {
            print("Discogs: No master found for \(artist) - \(album)")
            return nil
        }

        // Then fetch the master details which include images
        return await fetchMasterImages(masterId: masterId)
    }

    /// Fetch just the vinyl label image if available
    /// Discogs typically orders images: front cover (primary), back cover, label A, label B
    /// Secondary images are: [0]=back, [1]=label A, [2]=label B (indices in secondaryImages)
    func fetchVinylLabel(artist: String, album: String) async -> NSImage? {
        guard let images = await fetchImages(artist: artist, album: album) else {
            return nil
        }

        // Secondary images after primary: typically back cover, then labels
        // Try indices 1, 2, 3 (label A, label B, or additional labels)
        let potentialLabelIndices = [1, 2, 3, 0]

        for index in potentialLabelIndices {
            if index < images.secondaryImages.count {
                let image = images.secondaryImages[index]
                print("Discogs: Trying secondary image at index \(index) as potential vinyl label")
                if let labelImage = await downloadImage(from: image.uri) {
                    return labelImage
                }
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func searchForMaster(artist: String, album: String) async -> Int? {
        // Check cache first
        let cacheKey = "\(artist.lowercased())-\(album.lowercased())"
        if let cached = masterIdCache[cacheKey] {
            return cached
        }

        // Build search query
        let query = "\(artist) \(album)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "https://api.discogs.com/database/search?q=\(query)&type=master&per_page=5") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await urlSession.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return nil
            }

            // Find the best match - prefer exact artist match
            let artistLower = artist.lowercased()
            let albumLower = album.lowercased()

            for result in results {
                guard let title = result["title"] as? String,
                      let masterId = result["master_id"] as? Int else {
                    continue
                }

                let titleLower = title.lowercased()

                // Check if this matches our artist and album
                if titleLower.contains(artistLower) && titleLower.contains(albumLower) {
                    masterIdCache[cacheKey] = masterId
                    print("Discogs: Found master \(masterId) for '\(title)'")
                    return masterId
                }
            }

            // If no exact match, use first result if it exists
            if let firstResult = results.first,
               let masterId = firstResult["master_id"] as? Int {
                masterIdCache[cacheKey] = masterId
                print("Discogs: Using first result master \(masterId)")
                return masterId
            }

        } catch {
            print("Discogs search error: \(error)")
        }

        return nil
    }

    private func fetchMasterImages(masterId: Int) async -> DiscogsImages? {
        guard let url = URL(string: "https://api.discogs.com/masters/\(masterId)") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await urlSession.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let imagesArray = json["images"] as? [[String: Any]] else {
                return nil
            }

            var primaryImage: DiscogsImage?
            var secondaryImages: [DiscogsImage] = []

            for imageDict in imagesArray {
                guard let type = imageDict["type"] as? String,
                      let uri = imageDict["uri"] as? String,
                      let width = imageDict["width"] as? Int,
                      let height = imageDict["height"] as? Int else {
                    continue
                }

                let image = DiscogsImage(
                    type: type,
                    uri: uri,
                    uri150: imageDict["uri150"] as? String,
                    width: width,
                    height: height
                )

                if type == "primary" {
                    primaryImage = image
                } else {
                    secondaryImages.append(image)
                }
            }

            let title = json["title"] as? String ?? "Unknown"
            let year = json["year"] as? Int

            print("Discogs: Found \(1 + secondaryImages.count) images for master \(masterId)")

            return DiscogsImages(
                masterId: masterId,
                title: title,
                year: year,
                primaryImage: primaryImage,
                secondaryImages: secondaryImages
            )

        } catch {
            print("Discogs fetch master error: \(error)")
        }

        return nil
    }

    private func downloadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await urlSession.data(for: request)
            return NSImage(data: data)
        } catch {
            print("Discogs image download error: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models

struct DiscogsImages {
    let masterId: Int
    let title: String
    let year: Int?
    let primaryImage: DiscogsImage?
    let secondaryImages: [DiscogsImage]

    /// Get all images sorted by type (primary first)
    var allImages: [DiscogsImage] {
        var all: [DiscogsImage] = []
        if let primary = primaryImage {
            all.append(primary)
        }
        all.append(contentsOf: secondaryImages)
        return all
    }
}

struct DiscogsImage {
    let type: String  // "primary" or "secondary"
    let uri: String   // Full size image URL
    let uri150: String?  // Thumbnail URL
    let width: Int
    let height: Int

    var isLikelyVinylLabel: Bool {
        // Vinyl labels are typically:
        // - Square-ish aspect ratio
        // - Smaller than album covers (< 650px)
        // - Not the primary (cover) image
        let aspectRatio = Float(width) / Float(height)
        return type == "secondary" &&
               aspectRatio > 0.85 && aspectRatio < 1.15 &&
               width < 650 && width > 300
    }
}
