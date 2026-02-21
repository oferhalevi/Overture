import Foundation

/// Cache for storing facts per track
actor FactsCache {
    private var cache: [String: CacheEntry] = [:]

    struct CacheEntry {
        let facts: [Fact]
        let timestamp: Date
    }

    /// Get cached facts for a track
    func getFacts(for track: Track) -> [Fact]? {
        let key = cacheKey(for: track)

        guard let entry = cache[key] else {
            return nil
        }

        // Check if cache has expired
        if Date().timeIntervalSince(entry.timestamp) > Constants.Cache.factsCacheDuration {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.facts
    }

    /// Store facts for a track
    func setFacts(_ facts: [Fact], for track: Track) {
        let key = cacheKey(for: track)
        cache[key] = CacheEntry(facts: facts, timestamp: Date())
    }

    /// Clear the entire cache
    func clear() {
        cache.removeAll()
    }

    /// Clear expired entries
    func clearExpired() {
        let now = Date()
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= Constants.Cache.factsCacheDuration
        }
    }

    /// Generate cache key for a track
    private func cacheKey(for track: Track) -> String {
        "\(track.artist)|\(track.name)|\(track.album)"
    }
}
