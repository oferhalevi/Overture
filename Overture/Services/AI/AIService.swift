import Foundation
import AppKit

/// Unified AI service that handles all AI API calls using the configured provider
actor AIService {
    private let config = AIConfiguration.shared
    private let urlSession: URLSession

    init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 120  // 2 minutes for image generation
        self.urlSession = URLSession(configuration: sessionConfig)
    }

    // MARK: - Chat Completions

    /// Send a chat completion request and get text response
    func chatCompletion(
        prompt: String,
        maxTokens: Int = 600,
        temperature: Double = 0.7
    ) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        return try await chatCompletion(
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    /// Send a chat completion with custom messages array
    func chatCompletion(
        messages: [[String: Any]],
        maxTokens: Int = 600,
        temperature: Double = 0.7
    ) async throws -> String {
        guard let url = URL(string: config.chatCompletionsEndpoint) else {
            throw AIServiceError.invalidEndpoint
        }

        var requestBody: [String: Any]
        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]

        if config.provider == .anthropic {
            // Anthropic Messages API format
            let apiKey = config.apiKey
            guard !apiKey.isEmpty else {
                throw AIServiceError.missingAPIKey
            }

            headers["x-api-key"] = apiKey
            headers["anthropic-version"] = "2023-06-01"

            requestBody = [
                "model": config.chatModel,
                "max_tokens": maxTokens,
                "messages": messages
            ]
            if temperature != 1.0 {
                requestBody["temperature"] = temperature
            }
        } else {
            // OpenAI-compatible format
            requestBody = [
                "model": config.chatModel,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": maxTokens
            ]

            if config.provider.requiresAPIKey {
                let apiKey = config.apiKey
                guard !apiKey.isEmpty else {
                    throw AIServiceError.missingAPIKey
                }
                headers["Authorization"] = "Bearer \(apiKey)"
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("AIService: API error (\(httpResponse.statusCode)): \(errorBody.prefix(300))")
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse response based on provider
        if config.provider == .anthropic {
            // Anthropic returns: { "content": [{ "type": "text", "text": "..." }] }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                throw AIServiceError.parseError
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // OpenAI returns: { "choices": [{ "message": { "content": "..." } }] }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.parseError
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Vision (Image Analysis)

    /// Analyze an image with a text prompt
    func analyzeImage(
        image: NSImage,
        prompt: String,
        maxTokens: Int = 150
    ) async throws -> String {
        guard config.provider.supportsVision else {
            throw AIServiceError.visionNotSupported
        }

        // Create thumbnail and convert to base64
        guard let thumbnail = createThumbnail(from: image, size: 128),
              let jpegData = thumbnail.jpegData(compressionQuality: 0.6) else {
            throw AIServiceError.imageProcessingFailed
        }

        let base64Image = jpegData.base64EncodedString()

        let messages: [[String: Any]]

        if config.provider == .anthropic {
            // Anthropic vision format
            messages = [
                [
                    "role": "user",
                    "content": [
                        ["type": "image", "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64Image
                        ]],
                        ["type": "text", "text": prompt]
                    ]
                ]
            ]
        } else {
            // OpenAI vision format
            messages = [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            ]
        }

        return try await chatCompletion(messages: messages, maxTokens: maxTokens)
    }

    // MARK: - Image Generation

    /// Generate an image from a text prompt
    func generateImage(
        prompt: String,
        size: String = "512x512"
    ) async throws -> NSImage {
        guard config.imageGenerationEnabled else {
            throw AIServiceError.imageGenerationDisabled
        }

        guard config.provider.supportsImageGeneration else {
            throw AIServiceError.imageGenerationNotSupported
        }

        guard let url = URL(string: config.imageGenerationsEndpoint) else {
            throw AIServiceError.invalidEndpoint
        }

        let requestBody: [String: Any] = [
            "model": config.imageModel,
            "prompt": prompt,
            "n": 1,
            "size": size
        ]

        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]

        if config.provider.requiresAPIKey {
            let apiKey = config.apiKey
            guard !apiKey.isEmpty else {
                throw AIServiceError.missingAPIKey
            }
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("AIService: Image generation error (\(httpResponse.statusCode)): \(errorBody.prefix(300))")
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first else {
            throw AIServiceError.parseError
        }

        // Try b64_json first
        if let b64 = first["b64_json"] as? String,
           let imageData = Data(base64Encoded: b64),
           let image = NSImage(data: imageData) {
            return image
        }

        // Try URL fallback
        if let urlString = first["url"] as? String,
           let imageUrl = URL(string: urlString),
           let imageData = try? Data(contentsOf: imageUrl),
           let image = NSImage(data: imageData) {
            return image
        }

        throw AIServiceError.imageProcessingFailed
    }

    // MARK: - JSON Response

    /// Chat completion expecting a JSON array response
    func chatCompletionJSON(
        prompt: String,
        maxTokens: Int = 600,
        temperature: Double = 0.7
    ) async throws -> [String] {
        let content = try await chatCompletion(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature
        )

        // Try to parse as JSON array
        if let jsonData = content.data(using: .utf8),
           let facts = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            return facts
        }

        // Try to extract JSON from content
        if let start = content.firstIndex(of: "["),
           let end = content.lastIndex(of: "]") {
            let jsonString = String(content[start...end])
            if let jsonData = jsonString.data(using: .utf8),
               let facts = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
                return facts
            }
        }

        throw AIServiceError.parseError
    }

    // MARK: - Helper Methods

    private func createThumbnail(from image: NSImage, size: Int) -> NSImage? {
        let targetSize = NSSize(width: size, height: size)
        let newImage = NSImage(size: targetSize)

        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()

        return newImage
    }
}

// MARK: - NSImage Extension

private extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidEndpoint
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError
    case visionNotSupported
    case imageGenerationDisabled
    case imageGenerationNotSupported
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid API endpoint"
        case .missingAPIKey:
            return "API key is required but not configured"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .parseError:
            return "Failed to parse response"
        case .visionNotSupported:
            return "Vision is not supported by this provider"
        case .imageGenerationDisabled:
            return "Image generation is disabled"
        case .imageGenerationNotSupported:
            return "Image generation is not supported by this provider"
        case .imageProcessingFailed:
            return "Failed to process image"
        }
    }
}
