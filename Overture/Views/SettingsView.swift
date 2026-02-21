import SwiftUI

/// Settings view for configuring AI provider
struct SettingsView: View {
    @ObservedObject private var config = AIConfiguration.shared
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Settings content
            Form {
                Section("AI Provider") {
                    Picker("Provider", selection: $config.provider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Endpoint URL", text: $config.endpoint)
                        .textFieldStyle(.roundedBorder)

                    if config.provider.requiresAPIKey {
                        HStack {
                            if showingAPIKey {
                                TextField("API Key", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("API Key", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button(action: { showingAPIKey.toggle() }) {
                                Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                        }
                        .onChange(of: apiKeyInput) { newValue in
                            config.apiKey = newValue
                        }
                    }
                }

                Section("Models") {
                    TextField("Chat Model", text: $config.chatModel)
                        .textFieldStyle(.roundedBorder)

                    if config.provider.supportsImageGeneration {
                        TextField("Image Model", text: $config.imageModel)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Enable Image Generation", isOn: $config.imageGenerationEnabled)
                    }
                }

                Section("Provider Info") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Requires API Key", value: config.provider.requiresAPIKey ? "Yes" : "No")
                        InfoRow(label: "Supports Vision", value: config.provider.supportsVision ? "Yes" : "No")
                        InfoRow(label: "Supports Images", value: config.provider.supportsImageGeneration ? "Yes" : "No")

                        if config.isConfigured {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Configured")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("API key required")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        config.resetToDefaults()
                        apiKeyInput = ""
                    }
                    .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 500)
        .onAppear {
            apiKeyInput = config.apiKey
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    SettingsView()
}
