import Foundation

/// Service for generating narrative facts using the configured AI provider
actor LLMService {
    private let aiService = AIService()

    /// Truncate text to a maximum length, breaking at sentence boundaries when possible
    private func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }

        let truncated = String(text.prefix(maxLength))
        if let lastPeriod = truncated.lastIndex(of: ".") {
            return String(truncated[...lastPeriod])
        }
        return truncated
    }

    /// Generate a cohesive narrative about a track from Wikipedia context
    /// Returns facts with proper categories, avoiding repetition
    func generateNarrativeFacts(
        track: Track,
        artistSummary: String?,
        trackSummary: String?,
        albumSummary: String?
    ) async -> [Fact] {
        print("generateNarrativeFacts: starting for \(track.name)")

        // Build context from available Wikipedia data
        let maxSectionLength = 600
        var context = ""
        var availableSections: [String] = []

        if let trackInfo = trackSummary, !trackInfo.isEmpty {
            let truncated = truncate(trackInfo, maxLength: maxSectionLength)
            context += "ABOUT THE TRACK \"\(track.name)\":\n\(truncated)\n\n"
            availableSections.append("track")
        }
        if let artist = artistSummary, !artist.isEmpty {
            let truncated = truncate(artist, maxLength: maxSectionLength)
            context += "ABOUT THE ARTIST \(track.artist):\n\(truncated)\n\n"
            availableSections.append("artist")
        }
        if let album = albumSummary, !album.isEmpty {
            let truncated = truncate(album, maxLength: maxSectionLength)
            context += "ABOUT THE ALBUM \"\(track.album)\":\n\(truncated)"
            availableSections.append("album")
        }

        guard !context.isEmpty else {
            print("generateNarrativeFacts: no context available")
            return []
        }

        if context.count > 1800 {
            context = truncate(context, maxLength: 1800)
        }

        print("generateNarrativeFacts: context length = \(context.count) chars")

        // Build a prompt that generates distinct, non-repeating content
        let prompt = """
        I'm listening to "\(track.name)" by \(track.artist) from the album "\(track.album)".

        Here is factual information from Wikipedia:

        \(context)

        Write 3 SHORT paragraphs (2-3 sentences each) covering DIFFERENT aspects:

        1. THE TRACK: Focus on PRODUCTION, STYLE, and NOTABLE FACTS about "\(track.name)" - how it was recorded, its musical style, instruments used, chart performance, awards, or interesting trivia. Do NOT discuss lyrics or meaning.

        2. THE ARTIST: A brief, interesting fact about \(track.artist) - their background, career, musical style, or significance. Do NOT repeat anything from paragraph 1.

        3. THE ALBUM: Something about "\(track.album)" - when it was made, its themes, reception, or importance. Do NOT repeat information from paragraphs 1 or 2.

        Rules:
        - THE TRACK paragraph must focus on production/style/facts, NOT lyrics or meaning
        - Each paragraph must cover DIFFERENT information - no repetition
        - Be specific and factual based on the context provided
        - Keep each paragraph to 2-3 sentences maximum
        - Write in an engaging, journalistic style
        - Return as JSON array: ["paragraph1", "paragraph2", "paragraph3"]
        """

        do {
            print("generateNarrativeFacts: calling AI service...")
            let startTime = Date()
            let paragraphs = try await aiService.chatCompletionJSON(prompt: prompt)
            let elapsed = Date().timeIntervalSince(startTime)
            print("generateNarrativeFacts: AI returned \(paragraphs.count) paragraphs in \(String(format: "%.1f", elapsed))s")

            // Map to facts with appropriate categories
            var facts: [Fact] = []
            for (index, content) in paragraphs.enumerated() {
                let category: Fact.Category
                switch index {
                case 0: category = .track
                case 1: category = .artist
                case 2: category = .album
                default: category = .genre
                }
                facts.append(Fact(content: content, category: category, source: "AI Summary"))
            }
            return facts
        } catch {
            print("generateNarrativeFacts: error - \(error)")
            return []
        }
    }
}
