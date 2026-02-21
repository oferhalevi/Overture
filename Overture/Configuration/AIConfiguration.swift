import Foundation
import Security

/// AI Provider options
enum AIProvider: String, CaseIterable, Codable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case openRouter = "OpenRouter"
    case ollama = "Ollama"
    case custom = "Custom"

    var defaultEndpoint: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        case .ollama:
            return "http://localhost:11434/v1"
        case .custom:
            return "http://localhost:4242/v1"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama:
            return false
        default:
            return true
        }
    }

    var supportsImageGeneration: Bool {
        switch self {
        case .openAI, .custom:
            return true
        default:
            return false
        }
    }

    var supportsVision: Bool {
        switch self {
        case .openAI, .anthropic, .openRouter, .custom:
            return true
        case .ollama:
            return false  // Depends on model, but default to false
        }
    }

    var defaultChatModel: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .anthropic:
            return "claude-3-haiku-20240307"
        case .openRouter:
            return "anthropic/claude-3-haiku"
        case .ollama:
            return "llama3"
        case .custom:
            return "gpt-4.1-mini"
        }
    }

    var defaultImageModel: String {
        switch self {
        case .openAI:
            return "dall-e-3"
        case .custom:
            return "gpt-image-1"
        default:
            return ""
        }
    }

    var availableChatModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo"]
        case .anthropic:
            return [
                "claude-sonnet-4-20250514",
                "claude-3-5-sonnet-20241022",
                "claude-3-5-haiku-20241022",
                "claude-3-haiku-20240307",
                "claude-3-opus-20240229"
            ]
        case .openRouter:
            return [
                "anthropic/claude-sonnet-4",
                "anthropic/claude-3.5-sonnet",
                "anthropic/claude-3-haiku",
                "openai/gpt-4o",
                "openai/gpt-4o-mini",
                "google/gemini-pro-1.5",
                "meta-llama/llama-3.1-70b-instruct"
            ]
        case .ollama:
            return ["llama3.2", "llama3.1", "llama3", "mistral", "mixtral", "phi3", "gemma2"]
        case .custom:
            return ["gpt-4.1-mini", "gpt-4.1", "gpt-4o", "gpt-4o-mini"]
        }
    }

    var availableImageModels: [String] {
        switch self {
        case .openAI:
            return ["dall-e-3", "dall-e-2"]
        case .custom:
            return ["gpt-image-1", "dall-e-3"]
        default:
            return []
        }
    }
}

/// Configuration for AI services
class AIConfiguration: ObservableObject {
    static let shared = AIConfiguration()

    private let defaults = UserDefaults.standard
    private let keychainService = "com.overture.ai"

    // MARK: - Published Properties

    @Published var provider: AIProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: Keys.provider)
            // Reset endpoint to default when provider changes
            if endpoint != oldValue.defaultEndpoint {
                endpoint = provider.defaultEndpoint
            }
            // Reset models to defaults
            chatModel = provider.defaultChatModel
            imageModel = provider.defaultImageModel
        }
    }

    @Published var endpoint: String {
        didSet { defaults.set(endpoint, forKey: Keys.endpoint) }
    }

    @Published var chatModel: String {
        didSet { defaults.set(chatModel, forKey: Keys.chatModel) }
    }

    @Published var imageModel: String {
        didSet { defaults.set(imageModel, forKey: Keys.imageModel) }
    }

    @Published var imageGenerationEnabled: Bool {
        didSet { defaults.set(imageGenerationEnabled, forKey: Keys.imageGenerationEnabled) }
    }

    // MARK: - Computed Properties

    var chatCompletionsEndpoint: String {
        if provider == .anthropic {
            return "\(endpoint)/messages"
        }
        return "\(endpoint)/chat/completions"
    }

    var imageGenerationsEndpoint: String {
        "\(endpoint)/images/generations"
    }

    var isConfigured: Bool {
        if provider.requiresAPIKey {
            return !apiKey.isEmpty
        }
        return true
    }

    // MARK: - Keys

    private enum Keys {
        static let provider = "ai.provider"
        static let endpoint = "ai.endpoint"
        static let chatModel = "ai.chatModel"
        static let imageModel = "ai.imageModel"
        static let imageGenerationEnabled = "ai.imageGenerationEnabled"
        static let apiKeyAccount = "ai.apiKey"
    }

    // MARK: - Initialization

    private init() {
        // Load provider first
        let loadedProvider: AIProvider
        if let providerString = defaults.string(forKey: Keys.provider),
           let savedProvider = AIProvider(rawValue: providerString) {
            loadedProvider = savedProvider
        } else {
            loadedProvider = .custom  // Default to custom (local endpoint)
        }

        // Initialize all properties using loaded provider
        self.provider = loadedProvider
        self.endpoint = defaults.string(forKey: Keys.endpoint) ?? loadedProvider.defaultEndpoint
        self.chatModel = defaults.string(forKey: Keys.chatModel) ?? loadedProvider.defaultChatModel
        self.imageModel = defaults.string(forKey: Keys.imageModel) ?? loadedProvider.defaultImageModel

        // Load image generation setting
        if defaults.object(forKey: Keys.imageGenerationEnabled) != nil {
            self.imageGenerationEnabled = defaults.bool(forKey: Keys.imageGenerationEnabled)
        } else {
            self.imageGenerationEnabled = loadedProvider.supportsImageGeneration
        }
    }

    // MARK: - API Key (Keychain)

    var apiKey: String {
        get { loadFromKeychain(account: Keys.apiKeyAccount) ?? "" }
        set { saveToKeychain(value: newValue, account: Keys.apiKeyAccount) }
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(value: String, account: String) {
        let data = value.data(using: .utf8)!

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    // MARK: - Reset

    func resetToDefaults() {
        provider = .custom
        endpoint = provider.defaultEndpoint
        chatModel = provider.defaultChatModel
        imageModel = provider.defaultImageModel
        imageGenerationEnabled = provider.supportsImageGeneration
        apiKey = ""
    }
}
