import Foundation

/// Service for fetching information from Wikipedia
actor WikipediaAPIService {
    private let urlSession: URLSession
    private var lastRequestTime: Date?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.urlSession = URLSession(configuration: config)
    }

    /// Fetch Wikipedia summary for a search term
    func fetchSummary(for searchTerm: String) async throws -> WikipediaSummary? {
        // Rate limiting
        await enforceRateLimit()

        // First, search for the article
        guard let title = try await searchForArticle(searchTerm) else {
            return nil
        }

        // Then fetch the summary
        return try await fetchSummaryByTitle(title)
    }

    /// Search Wikipedia for an article matching the term
    private func searchForArticle(_ term: String) async throws -> String? {
        let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encodedTerm)&format=json&srlimit=1"

        guard let url = URL(string: urlString) else {
            return nil
        }

        let (data, _) = try await urlSession.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? [String: Any],
              let search = query["search"] as? [[String: Any]],
              let firstResult = search.first,
              let title = firstResult["title"] as? String else {
            return nil
        }

        return title
    }

    /// Fetch summary for a specific Wikipedia article title
    private func fetchSummaryByTitle(_ title: String) async throws -> WikipediaSummary? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://en.wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try? decoder.decode(WikipediaSummary.self, from: data)
    }

    /// Enforce rate limiting (1 request per second)
    private func enforceRateLimit() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < Constants.Timing.wikipediaRateLimit {
                let waitTime = Constants.Timing.wikipediaRateLimit - elapsed
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
}

/// Wikipedia summary response
struct WikipediaSummary: Decodable {
    let title: String
    let extract: String
    let description: String?
    let thumbnail: Thumbnail?

    struct Thumbnail: Decodable {
        let source: String
    }
}
