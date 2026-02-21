import SwiftUI

/// Settings view for configuring AI provider - Raycast-inspired design
struct SettingsView: View {
    @ObservedObject private var config = AIConfiguration.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult?
    @State private var customChatModel: String = ""
    @State private var customImageModel: String = ""
    @State private var showCustomChatInput = false
    @State private var showCustomImageInput = false

    enum VerificationResult {
        case success(String)
        case failure(String)
    }

    private let rowBackgroundColor = Color(nsColor: .controlBackgroundColor)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Provider Section
                settingsSection("Provider") {
                    settingsRow(label: "Provider") {
                        Picker("", selection: $config.provider) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }

                    settingsRow(label: "Endpoint") {
                        TextField("", text: $config.endpoint)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }

                    if config.provider.requiresAPIKey {
                        settingsRow(label: "API Key") {
                            HStack(spacing: 8) {
                                Group {
                                    if showingAPIKey {
                                        TextField("", text: $apiKeyInput)
                                    } else {
                                        SecureField("", text: $apiKeyInput)
                                    }
                                }
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                                .onChange(of: apiKeyInput) { newValue in
                                    config.apiKey = newValue
                                }

                                Button(action: { showingAPIKey.toggle() }) {
                                    Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    settingsRow(label: "Connection") {
                        HStack(spacing: 12) {
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
                                        .lineLimit(1)
                                        .frame(maxWidth: 150)
                                }
                            }

                            Button(action: verifyConnection) {
                                HStack(spacing: 6) {
                                    if isVerifying {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.7)
                                    }
                                    Text(isVerifying ? "Verifying..." : "Verify")
                                }
                                .frame(width: 80)
                            }
                            .disabled(isVerifying || (config.provider.requiresAPIKey && apiKeyInput.isEmpty))
                        }
                    }
                }

                // Models Section
                settingsSection("Models") {
                    settingsRow(label: "Chat Model") {
                        modelPicker(
                            selection: $config.chatModel,
                            models: config.provider.availableChatModels,
                            showCustomInput: $showCustomChatInput,
                            customValue: $customChatModel
                        )
                    }

                    if config.provider.supportsImageGeneration {
                        settingsRow(label: "Image Model") {
                            modelPicker(
                                selection: $config.imageModel,
                                models: config.provider.availableImageModels,
                                showCustomInput: $showCustomImageInput,
                                customValue: $customImageModel
                            )
                        }

                        settingsRow(label: "Image Generation") {
                            Toggle("", isOn: $config.imageGenerationEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                }

                // Capabilities Section
                settingsSection("Capabilities") {
                    statusRow(label: "Vision Support", enabled: config.provider.supportsVision)
                    statusRow(label: "Image Generation", enabled: config.provider.supportsImageGeneration)
                    statusRow(label: "API Key Required", enabled: config.provider.requiresAPIKey)
                }

                // Reset
                HStack {
                    Spacer()
                    Button(action: {
                        config.resetToDefaults()
                        apiKeyInput = ""
                        verificationResult = nil
                    }) {
                        Text("Reset to Defaults")
                    }
                    .foregroundColor(.red)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .frame(width: 450, height: 480)
        .onAppear {
            apiKeyInput = config.apiKey
        }
    }

    // MARK: - Components

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)

            Spacer()

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statusRow(label: String, enabled: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(enabled ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(enabled ? "Yes" : "No")
                    .foregroundColor(enabled ? .primary : .secondary)
            }
            .frame(width: 260, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func modelPicker(
        selection: Binding<String>,
        models: [String],
        showCustomInput: Binding<Bool>,
        customValue: Binding<String>
    ) -> some View {
        Group {
            if showCustomInput.wrappedValue {
                HStack(spacing: 8) {
                    TextField("Enter model name", text: customValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onSubmit {
                            if !customValue.wrappedValue.isEmpty {
                                selection.wrappedValue = customValue.wrappedValue
                            }
                            showCustomInput.wrappedValue = false
                        }

                    Button("Done") {
                        if !customValue.wrappedValue.isEmpty {
                            selection.wrappedValue = customValue.wrappedValue
                        }
                        showCustomInput.wrappedValue = false
                    }
                    .controlSize(.small)
                }
            } else {
                Picker("", selection: selection) {
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                    Divider()
                    Text("Custom...").tag("__custom__")
                }
                .labelsHidden()
                .frame(width: 260)
                .onChange(of: selection.wrappedValue) { newValue in
                    if newValue == "__custom__" {
                        customValue.wrappedValue = ""
                        showCustomInput.wrappedValue = true
                        if let first = models.first {
                            selection.wrappedValue = first
                        }
                    }
                }
            }
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
                        verificationResult = .success("Connected!")
                    } else {
                        verificationResult = .success("Connected")
                    }
                }
            } catch let error as AIServiceError {
                await MainActor.run {
                    isVerifying = false
                    switch error {
                    case .apiError(let code, _):
                        verificationResult = .failure("Error \(code)")
                    default:
                        verificationResult = .failure(error.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    verificationResult = .failure("Failed")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
