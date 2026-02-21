import Foundation
import AppKit

/// Service for generating vinyl label images using AI
actor LabelGeneratorService {
    private let aiService = AIService()
    private let config = AIConfiguration.shared
    private var cache: [String: NSImage] = [:]

    /// Generate a vinyl label sticker based on album metadata and artwork style
    func generateLabel(
        artist: String,
        album: String,
        albumArtwork: NSImage?
    ) async -> NSImage? {
        // Check if image generation is enabled
        guard config.imageGenerationEnabled && config.provider.supportsImageGeneration else {
            print("LabelGenerator: image generation not available for current provider")
            return nil
        }

        let cacheKey = "\(artist)-\(album)"

        // Check cache first
        if let cached = cache[cacheKey] {
            print("LabelGenerator: using cached label for \(artist) - \(album)")
            return cached
        }

        print("LabelGenerator: generating label for \(artist) - \(album)")
        let startTime = Date()

        // First, analyze the album artwork to understand its style
        var styleDescription = "classic vintage record label with warm colors"
        if let artwork = albumArtwork, config.provider.supportsVision {
            if let analysis = await analyzeArtworkStyle(artwork, artist: artist, album: album) {
                styleDescription = analysis
            }
        }

        // Generate the label image based on the style analysis
        let image = await generateLabelImage(
            artist: artist,
            album: album,
            styleDescription: styleDescription
        )

        let elapsed = Date().timeIntervalSince(startTime)
        print("LabelGenerator: completed in \(String(format: "%.1f", elapsed))s")

        if let image = image {
            cache[cacheKey] = image
        }

        return image
    }

    /// Analyze album artwork style for consistency
    private func analyzeArtworkStyle(_ image: NSImage, artist: String, album: String) async -> String? {
        let prompt = """
        Describe the visual style of this album cover in 2-3 sentences for creating a matching vinyl record label. \
        Focus on: color palette, mood, artistic style (vintage, modern, minimalist, psychedelic, etc.), \
        key visual elements or motifs, and typography style if visible. Be concise and specific.
        """

        do {
            let analysisStart = Date()
            let result = try await aiService.analyzeImage(image: image, prompt: prompt, maxTokens: 150)
            let analysisTime = Date().timeIntervalSince(analysisStart)
            print("LabelGenerator: vision analysis in \(String(format: "%.1f", analysisTime))s")
            print("LabelGenerator: style analysis = \(result.prefix(100))...")
            return result
        } catch {
            print("LabelGenerator: vision error - \(error)")
            return nil
        }
    }

    /// Generate the label image based on style description
    private func generateLabelImage(
        artist: String,
        album: String,
        styleDescription: String
    ) async -> NSImage? {
        let prompt = """
        Design a circular vinyl record center label for "\(album)" by \(artist).

        Style reference from album art: \(styleDescription)

        Design requirements:
        - Circular format, will be used as vinyl center label
        - Incorporate visual elements, imagery, and artistic motifs inspired by the album art style
        - Include artist name and album title with elegant typography
        - Rich colors that complement the album art palette
        - Professional record label design (like Blue Note, Columbia, ECM aesthetics)
        - Small center hole for the spindle
        - The label should feel like an artistic extension of the album cover, not just text
        """

        print("LabelGenerator: generating image...")

        do {
            let genStart = Date()
            let image = try await aiService.generateImage(prompt: prompt, size: "512x512")
            let genTime = Date().timeIntervalSince(genStart)
            print("LabelGenerator: image generation in \(String(format: "%.1f", genTime))s")
            return image
        } catch {
            print("LabelGenerator: generation error - \(error)")
            return nil
        }
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }
}
