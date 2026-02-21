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
    @Environment(\.dismiss) private var dismiss

    enum VerificationResult {
        case success(String)
        case failure(String)
    }

    private let backgroundColor = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let rowBackgroundColor = Color(red: 0.18, green: 0.18, blue: 0.19)
    private let separatorColor = Color(white: 0.25)

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Provider Section
                    settingsSection {
                        settingsRow(label: "Provider") {
                            Picker("", selection: $config.provider) {
                                ForEach(AIProvider.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 280)
                        }

                        settingsRow(label: "Endpoint") {
                            TextField("", text: $config.endpoint)
                                .textFieldStyle(.plain)
                                .frame(width: 280)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(rowBackgroundColor)
                                .cornerRadius(6)
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
                                    .textFieldStyle(.plain)
                                    .frame(width: 230)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(rowBackgroundColor)
                                    .cornerRadius(6)
                                    .onChange(of: apiKeyInput) { newValue in
                                        config.apiKey = newValue
                                    }

                                    Button(action: { showingAPIKey.toggle() }) {
                                        Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Models Section
                    settingsSection {
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

                    // Connection Section
                    settingsSection {
                        HStack {
                            Text("Connection")
                                .foregroundColor(.gray)
                                .frame(width: 140, alignment: .trailing)

                            Spacer()

                            HStack(spacing: 12) {
                                if let result = verificationResult {
                                    switch result {
                                    case .success(let message):
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text(message)
                                                .foregroundColor(.green)
                                        }
                                        .font(.caption)
                                    case .failure(let message):
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                            Text(message)
                                                .foregroundColor(.red)
                                                .lineLimit(1)
                                        }
                                        .font(.caption)
                                        .frame(maxWidth: 180)
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
                                .buttonStyle(.bordered)
                                .disabled(isVerifying || (config.provider.requiresAPIKey && apiKeyInput.isEmpty))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }

                    // Status indicators
                    settingsSection {
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
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 560)
        .background(backgroundColor)
        .preferredColorScheme(.dark)
        .onAppear {
            apiKeyInput = config.apiKey
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
    }

    // MARK: - Components

    private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.15))
        )
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .trailing)

            Spacer()

            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func statusRow(label: String, enabled: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .trailing)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(enabled ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(enabled ? "Yes" : "No")
                    .foregroundColor(enabled ? .white : .gray)
                    .font(.system(size: 13))
            }
            .frame(width: 280, alignment: .leading)
        }
        .padding(.horizontal, 20)
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
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(rowBackgroundColor)
                        .cornerRadius(6)
                        .frame(width: 220)
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
                    .buttonStyle(.bordered)
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
                .frame(width: 280)
                .onChange(of: selection.wrappedValue) { newValue in
                    if newValue == "__custom__" {
                        customValue.wrappedValue = ""
                        showCustomInput.wrappedValue = true
                        // Reset to first model temporarily
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
