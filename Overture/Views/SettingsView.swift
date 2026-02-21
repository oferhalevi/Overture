import SwiftUI

/// Settings view for configuring AI provider
struct SettingsView: View {
    @ObservedObject private var config = AIConfiguration.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult?
    @State private var customChatModel: String = ""
    @State private var showCustomChatInput = false

    enum VerificationResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // MARK: - Provider & Connection
                Section {
                    Picker("Provider", selection: $config.provider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }

                    if showCustomChatInput {
                        HStack {
                            Text("Model")
                            Spacer()
                            TextField("Model name", text: $customChatModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                                .onSubmit { applyCustomModel() }
                            Button("Set") { applyCustomModel() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    } else {
                        Picker("Model", selection: $config.chatModel) {
                            ForEach(config.provider.availableChatModels, id: \.self) { model in
                                Text(shortModelName(model)).tag(model)
                            }
                            Divider()
                            Text("Custom…").tag("__custom__")
                        }
                        .onChange(of: config.chatModel) { newValue in
                            if newValue == "__custom__" {
                                customChatModel = ""
                                showCustomChatInput = true
                                config.chatModel = config.provider.availableChatModels.first ?? ""
                            }
                        }
                    }

                    LabeledContent("Endpoint") {
                        TextField("", text: $config.endpoint)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    }

                    if config.provider.requiresAPIKey {
                        LabeledContent("API Key") {
                            HStack(spacing: 6) {
                                Group {
                                    if showingAPIKey {
                                        TextField("", text: $apiKeyInput)
                                    } else {
                                        SecureField("", text: $apiKeyInput)
                                    }
                                }
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                                .onChange(of: apiKeyInput) { config.apiKey = $0 }

                                Button(action: { showingAPIKey.toggle() }) {
                                    Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Connection")
                }

                // MARK: - Test Connection
                Section {
                    HStack {
                        connectionStatus
                        Spacer()
                        Button(action: verifyConnection) {
                            Group {
                                if isVerifying {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Test Connection")
                                }
                            }
                            .frame(width: 100)
                        }
                        .disabled(isVerifying || (config.provider.requiresAPIKey && apiKeyInput.isEmpty))
                    }
                }

                // MARK: - Image Generation (if supported)
                if config.provider.supportsImageGeneration {
                    Section {
                        Toggle("Enable Image Generation", isOn: $config.imageGenerationEnabled)

                        if config.imageGenerationEnabled {
                            Picker("Image Model", selection: $config.imageModel) {
                                ForEach(config.provider.availableImageModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                        }
                    } header: {
                        Text("Image Generation")
                    }
                }

                // MARK: - About
                Section {
                    HStack(spacing: 16) {
                        capabilityBadge("Vision", enabled: config.provider.supportsVision)
                        capabilityBadge("Images", enabled: config.provider.supportsImageGeneration)
                        capabilityBadge("Local", enabled: !config.provider.requiresAPIKey)
                        Spacer()
                    }
                } header: {
                    Text("Provider Capabilities")
                }

                // MARK: - Reset
                Section {
                    HStack {
                        Spacer()
                        Button("Reset to Defaults", role: .destructive) {
                            config.resetToDefaults()
                            apiKeyInput = ""
                            verificationResult = nil
                            showCustomChatInput = false
                        }
                        Spacer()
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 420)
        .onAppear {
            apiKeyInput = config.apiKey
        }
    }

    // MARK: - Connection Status

    @ViewBuilder
    private var connectionStatus: some View {
        switch verificationResult {
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.callout)
        case .failure(let error):
            Label(error, systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.callout)
                .lineLimit(1)
        case nil:
            if config.isConfigured {
                Label("Ready", systemImage: "circle.fill")
                    .foregroundColor(.secondary)
                    .font(.callout)
            } else {
                Label("Not configured", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.callout)
            }
        }
    }

    // MARK: - Capability Badge

    private func capabilityBadge(_ label: String, enabled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: enabled ? "checkmark" : "xmark")
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(enabled ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
        )
        .foregroundColor(enabled ? .green : .secondary)
    }

    // MARK: - Helpers

    private func shortModelName(_ model: String) -> String {
        // Shorten long model names for display
        model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
            .replacingOccurrences(of: "google/", with: "")
            .replacingOccurrences(of: "meta-llama/", with: "")
    }

    private func applyCustomModel() {
        if !customChatModel.isEmpty {
            config.chatModel = customChatModel
        }
        showCustomChatInput = false
    }

    // MARK: - Verify Connection

    private func verifyConnection() {
        isVerifying = true
        verificationResult = nil

        Task {
            do {
                let aiService = AIService()
                _ = try await aiService.chatCompletion(
                    prompt: "Say OK",
                    maxTokens: 5,
                    temperature: 0
                )
                await MainActor.run {
                    isVerifying = false
                    verificationResult = .success
                }
            } catch let error as AIServiceError {
                await MainActor.run {
                    isVerifying = false
                    switch error {
                    case .apiError(let code, _):
                        verificationResult = .failure("Error \(code)")
                    case .missingAPIKey:
                        verificationResult = .failure("Missing API key")
                    default:
                        verificationResult = .failure("Failed")
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    verificationResult = .failure("Connection failed")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
