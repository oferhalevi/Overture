import SwiftUI

/// Settings view for configuring AI provider
struct SettingsView: View {
    @ObservedObject private var config = AIConfiguration.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult?
    @Environment(\.dismiss) private var dismiss

    enum VerificationResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    providerCard
                    modelsCard
                    statusCard
                    resetSection
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            apiKeyInput = config.apiKey
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Configure your AI provider")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Provider Card

    private var providerCard: some View {
        SettingsCard(title: "AI Provider", icon: "cpu") {
            VStack(spacing: 16) {
                // Provider picker
                HStack {
                    Text("Provider")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $config.provider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Divider()

                // Endpoint
                VStack(alignment: .leading, spacing: 6) {
                    Text("Endpoint URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("https://api.example.com/v1", text: $config.endpoint)
                        .textFieldStyle(.roundedBorder)
                }

                // API Key (if required)
                if config.provider.requiresAPIKey {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Group {
                                if showingAPIKey {
                                    TextField("sk-...", text: $apiKeyInput)
                                } else {
                                    SecureField("sk-...", text: $apiKeyInput)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKeyInput) { newValue in
                                config.apiKey = newValue
                            }

                            Button(action: { showingAPIKey.toggle() }) {
                                Image(systemName: showingAPIKey ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(showingAPIKey ? "Hide API key" : "Show API key")
                        }
                    }
                }

                // Verify button
                Divider()

                HStack {
                    if let result = verificationResult {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                    Button(action: verifyConnection) {
                        HStack(spacing: 6) {
                            if isVerifying {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(isVerifying ? "Verifying..." : "Verify Connection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isVerifying || (config.provider.requiresAPIKey && apiKeyInput.isEmpty))
                }
            }
        }
    }

    // MARK: - Models Card

    private var modelsCard: some View {
        SettingsCard(title: "Models", icon: "brain") {
            VStack(spacing: 16) {
                // Chat model picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chat Model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Picker("", selection: $config.chatModel) {
                            ForEach(config.provider.availableChatModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()

                        // Custom model input
                        TextField("or enter custom", text: $config.chatModel)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }
                }

                // Image generation (if supported)
                if config.provider.supportsImageGeneration {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Image Model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Picker("", selection: $config.imageModel) {
                                ForEach(config.provider.availableImageModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .labelsHidden()

                            TextField("or enter custom", text: $config.imageModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }
                    }

                    Divider()

                    Toggle(isOn: $config.imageGenerationEnabled) {
                        HStack {
                            Image(systemName: "photo.artframe")
                                .foregroundColor(.secondary)
                            Text("Enable Image Generation")
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        SettingsCard(title: "Provider Capabilities", icon: "info.circle") {
            VStack(spacing: 12) {
                StatusRow(
                    label: "API Key Required",
                    isEnabled: config.provider.requiresAPIKey,
                    enabledText: "Yes",
                    disabledText: "No"
                )
                StatusRow(
                    label: "Vision Support",
                    isEnabled: config.provider.supportsVision,
                    enabledText: "Supported",
                    disabledText: "Not supported"
                )
                StatusRow(
                    label: "Image Generation",
                    isEnabled: config.provider.supportsImageGeneration,
                    enabledText: "Supported",
                    disabledText: "Not supported"
                )

                Divider()

                HStack {
                    if config.isConfigured {
                        Label("Ready to use", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("API key required", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        HStack {
            Spacer()
            Button(action: {
                config.resetToDefaults()
                apiKeyInput = ""
                verificationResult = nil
            }) {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
    }

    // MARK: - Verify Connection

    private func verifyConnection() {
        isVerifying = true
        verificationResult = nil

        Task {
            do {
                let aiService = AIService()
                let response = try await aiService.chatCompletion(
                    prompt: "Say 'OK' and nothing else.",
                    maxTokens: 10,
                    temperature: 0
                )

                await MainActor.run {
                    isVerifying = false
                    if response.lowercased().contains("ok") {
                        verificationResult = .success("Connection successful!")
                    } else {
                        verificationResult = .success("Connected (got response)")
                    }
                }
            } catch let error as AIServiceError {
                await MainActor.run {
                    isVerifying = false
                    verificationResult = .failure(error.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    verificationResult = .failure("Connection failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Settings Card Component

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            // Card content
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Status Row Component

struct StatusRow: View {
    let label: String
    let isEnabled: Bool
    let enabledText: String
    let disabledText: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(isEnabled ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(isEnabled ? enabledText : disabledText)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    SettingsView()
}
