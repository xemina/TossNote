import Foundation
import SwiftUI

// MARK: - View Model for Content Organization

struct AIConfigurationStatus: Equatable {
    let isReady: Bool
    let message: String
}

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var selectedProvider: String = "OpenAI" {
        didSet {
            guard selectedProvider != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            KeychainStore.save(apiKey, account: apiKeyAccount(for: oldValue))
            UserDefaults.standard.set(selectedModel, forKey: "modelName_\(oldValue)")
            UserDefaults.standard.set(customAPIURL, forKey: "apiURL_\(oldValue)")
            isLoadingStoredSettings = true
            apiKey = storedAPIKey(for: selectedProvider)
            selectedModel = storedModel(for: selectedProvider)
            customAPIURL = storedEndpoint(for: selectedProvider)
            updateAvailableModels()
            isLoadingStoredSettings = false
            persistSettings()
            clearAIConnectionTest()
            refreshAIConfigurationStatus()
        }
    }
    @Published var selectedModel: String = "gpt-5" {
        didSet {
            guard selectedModel != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            persistSettings()
            clearAIConnectionTest()
            refreshAIConfigurationStatus()
        }
    }
    @Published var apiKey: String = "" {
        didSet {
            guard apiKey != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            persistSettings()
            clearAIConnectionTest()
            refreshAIConfigurationStatus()
        }
    }
    @Published var customAPIURL: String = "" {
        didSet {
            guard customAPIURL != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            persistSettings()
            clearAIConnectionTest()
            refreshAIConfigurationStatus()
        }
    }
    @Published var customAPIFormat: CustomAPIFormat = .openAIChatCompletions {
        didSet {
            guard customAPIFormat != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            persistSettings()
            clearAIConnectionTest()
            refreshAIConfigurationStatus()
        }
    }
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var lastLatency: TimeInterval = 0
    @Published var customSystemPrompt = "" {
        didSet {
            guard customSystemPrompt != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            persistSettings()
        }
    }
    @Published var customTitleFormat = "" {
        didSet {
            guard customTitleFormat != oldValue else { return }
            guard !isLoadingStoredSettings else { return }
            persistSettings()
        }
    }
    @Published private(set) var aiConfigurationStatus = AIConfigurationStatus(
        isReady: false,
        message: "Checking AI configuration..."
    )
    @Published var isTestingAIConnection = false
    @Published var aiConnectionTestMessage: String?
    @Published var aiConnectionTestSucceeded: Bool?
    
    private let client = OpenAIClient()
    private let registry = AIProviderRegistry.shared
    private var isLoadingStoredSettings = false
    
    var availableProviders: [String] {
        registry.allProviderNames()
    }
    
    var availableModels: [String] {
        if let provider = registry.provider(for: selectedProvider) {
            return provider.models
        }
        
        return []
    }
    
    var usesFreeformModel: Bool {
        selectedProvider == "Custom" || availableModels.isEmpty
    }
    
    var usesEditableEndpoint: Bool {
        selectedProvider == "Custom" || selectedProvider == "OpenRouter" || selectedProvider == "AnyRouter"
    }
    
    var defaultModel: String {
        if selectedProvider == "Custom" {
            return ""
        }
        
        if let provider = registry.provider(for: selectedProvider) {
            return provider.defaultModel
        }
        return ""
    }
    
    var defaultURL: String {
        if let provider = registry.provider(for: selectedProvider) {
            return provider.defaultURL
        }
        return ""
    }
    
    var defaultSystemPrompt: String {
        OpenAICompatibleProvider.defaultSystemPrompt
    }
    
    var effectiveSystemPrompt: String {
        let trimmedPrompt = customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let basePrompt = trimmedPrompt.isEmpty ? defaultSystemPrompt : trimmedPrompt
        return promptWithTitleFormat(basePrompt)
    }
    
    var isUsingCustomPrompt: Bool {
        !customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var currentURL: URL? {
        let endpoint = usesEditableEndpoint ? customAPIURL : defaultURL
        let urlString = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: urlString)
    }
    
    init() {
        loadStoredSettings()
        updateAvailableModels()
        refreshAIConfigurationStatus()
    }
    
    private func loadStoredSettings() {
        isLoadingStoredSettings = true
        defer { isLoadingStoredSettings = false }
        
        selectedProvider = UserDefaults.standard.string(forKey: "aiProvider") ?? "OpenAI"
        selectedModel = storedModel(for: selectedProvider)
        apiKey = storedAPIKey(for: selectedProvider)
        customAPIURL = storedEndpoint(for: selectedProvider)
        customAPIFormat = storedCustomAPIFormat()
        customSystemPrompt = UserDefaults.standard.string(forKey: "customSystemPrompt") ?? ""
        customTitleFormat = UserDefaults.standard.string(forKey: "customTitleFormat") ?? ""
    }
    
    func saveSettings() {
        persistSettings()
        refreshAIConfigurationStatus()
    }
    
    private func persistSettings() {
        guard !isLoadingStoredSettings else { return }
        UserDefaults.standard.set(selectedProvider, forKey: "aiProvider")
        UserDefaults.standard.set(selectedModel, forKey: "modelName")
        UserDefaults.standard.set(selectedModel, forKey: "modelName_\(selectedProvider)")
        KeychainStore.save(apiKey, account: apiKeyAccount(for: selectedProvider))
        UserDefaults.standard.set(customAPIURL, forKey: "customAPIURL")
        UserDefaults.standard.set(customAPIURL, forKey: "apiURL_\(selectedProvider)")
        UserDefaults.standard.set(customAPIFormat.rawValue, forKey: "customAPIFormat")
        UserDefaults.standard.set(customSystemPrompt, forKey: "customSystemPrompt")
        UserDefaults.standard.set(customTitleFormat, forKey: "customTitleFormat")
    }
    
    func restoreDefaultPrompt() {
        customSystemPrompt = ""
    }

    func restoreDefaultTitleFormat() {
        customTitleFormat = ""
    }

    func restoreDefaultEndpoint() {
        guard selectedProvider != "Custom" else { return }
        customAPIURL = defaultURL
    }

    private func promptWithTitleFormat(_ prompt: String) -> String {
        let trimmedTitleFormat = customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitleFormat.isEmpty else { return prompt }

        return """
        \(prompt)

        Custom title rule:
        - The Markdown note must start with exactly one H1 title line.
        - The H1 title must follow this user-defined format: \(trimmedTitleFormat)
        - Replace placeholders with concise values inferred from the input.
        - Supported placeholders include {{date}}, {{topic}}, {{source}}, {{type}}, {{project}}, {{person}}, and {{language}}.
        - If a placeholder value is unavailable, omit that part cleanly without leaving braces.
        """
    }
    
    func updateAvailableModels() {
        let models = availableModels
        if !models.isEmpty && !models.contains(selectedModel) {
            selectedModel = models[0]
        } else if models.isEmpty && selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedModel = defaultModel
        }
    }
    
    private func storedModel(for provider: String) -> String {
        if let stored = UserDefaults.standard.string(forKey: "modelName_\(provider)") {
            return stored
        }
        
        if provider == selectedProvider,
           let legacyStored = UserDefaults.standard.string(forKey: "modelName") {
            return legacyStored
        }
        
        if provider == "Custom" {
            return ""
        }
        
        return registry.provider(for: provider)?.defaultModel ?? ""
    }

    private func storedAPIKey(for provider: String) -> String {
        let account = apiKeyAccount(for: provider)
        let keychainValue = KeychainStore.read(account: account)
        if !keychainValue.isEmpty {
            return keychainValue
        }

        let legacyKey = "apiKey_\(provider)"
        guard let legacyValue = UserDefaults.standard.string(forKey: legacyKey),
              !legacyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        KeychainStore.save(legacyValue, account: account)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return legacyValue
    }

    private func apiKeyAccount(for provider: String) -> String {
        "ai-api-key-\(provider)"
    }
    
    private func storedEndpoint(for provider: String) -> String {
        if let stored = UserDefaults.standard.string(forKey: "apiURL_\(provider)") {
            return stored
        }
        
        if provider == "Custom",
           let legacyStored = UserDefaults.standard.string(forKey: "customAPIURL") {
            return legacyStored
        }
        
        return registry.provider(for: provider)?.defaultURL ?? ""
    }

    private func storedCustomAPIFormat() -> CustomAPIFormat {
        guard let rawValue = UserDefaults.standard.string(forKey: "customAPIFormat"),
              let format = CustomAPIFormat(rawValue: rawValue) else {
            return .openAIChatCompletions
        }

        return format
    }
    
    func validateAISetup() -> (isValid: Bool, message: String?) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndpoint = (usesEditableEndpoint ? customAPIURL : defaultURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedKey.isEmpty {
            return (false, "❌ API key is not configured for \(selectedProvider).\n\nPlease go to Settings and add your API key.")
        }
        
        if trimmedModel.isEmpty {
            return (false, "❌ Model is not configured for \(selectedProvider).\n\nPlease choose or enter a model.")
        }
        
        if trimmedEndpoint.isEmpty {
            return (false, "❌ API endpoint is not configured for \(selectedProvider).\n\nPlease enter the full API endpoint.")
        }
        
        guard let apiURL = currentURL else {
            return (false, "❌ Invalid API URL for \(selectedProvider).\n\nPlease check Settings.")
        }
        
        if apiURL.scheme == nil || apiURL.host == nil {
            return (false, "❌ Invalid API URL format.\n\nPlease check Settings.")
        }

        guard URLSafety.isSecureRemoteEndpoint(apiURL) else {
            return (false, "❌ AI endpoint must use HTTPS.\n\nThis protects your API key from being sent over an unencrypted connection.")
        }
        
        return (true, nil)
    }
    
    func refreshAIConfigurationStatus() {
        let validation = validateAISetup()
        
        if validation.isValid {
            let modelPart = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ""
                : " / \(selectedModel)"
            aiConfigurationStatus = AIConfigurationStatus(
                isReady: true,
                message: "AI Ready: \(selectedProvider)\(modelPart)"
            )
            
            if isConfigurationError(errorMessage) {
                errorMessage = nil
            }
        } else {
            aiConfigurationStatus = AIConfigurationStatus(
                isReady: false,
                message: compactConfigurationMessage()
            )
        }
    }
    
    func markAIUnavailable(_ message: String) {
        aiConfigurationStatus = AIConfigurationStatus(
            isReady: false,
            message: message
        )
    }
    
    private func compactConfigurationMessage() -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndpoint = (usesEditableEndpoint ? customAPIURL : defaultURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedKey.isEmpty {
            return "AI unavailable: \(selectedProvider) API key missing"
        }
        
        if trimmedModel.isEmpty {
            return "AI unavailable: \(selectedProvider) model missing"
        }
        
        if trimmedEndpoint.isEmpty {
            return "AI unavailable: \(selectedProvider) endpoint missing"
        }
        
        guard let apiURL = currentURL,
              apiURL.scheme != nil,
              apiURL.host != nil else {
            return "AI unavailable: invalid \(selectedProvider) API URL"
        }

        guard URLSafety.isSecureRemoteEndpoint(apiURL) else {
            return "AI unavailable: endpoint must use HTTPS"
        }
        
        return "AI unavailable"
    }
    
    private func isConfigurationError(_ message: String?) -> Bool {
        guard let message else { return false }
        return message.contains("API key is not configured")
            || message.contains("Invalid API URL")
            || message.contains("Invalid API URL format")
            || message.contains("API endpoint is not configured")
            || message.contains("Model is not configured")
            || message.contains("AI endpoint must use HTTPS")
            || message.contains("AI Connection Test Failed")
    }
    
    private func clearAIConnectionTest() {
        aiConnectionTestMessage = nil
        aiConnectionTestSucceeded = nil
    }
    
    func testAIConnection() async {
        refreshAIConfigurationStatus()
        let validation = validateAISetup()
        
        guard validation.isValid else {
            aiConnectionTestSucceeded = false
            aiConnectionTestMessage = compactConfigurationMessage()
            markAIUnavailable(compactConfigurationMessage())
            return
        }
        
        isTestingAIConnection = true
        aiConnectionTestMessage = nil
        aiConnectionTestSucceeded = nil
        defer { isTestingAIConnection = false }
        
        do {
            let result = try await client.organize(
                input: "Connection test. Return a short Markdown note with the title AI Test.",
                apiKey: apiKey,
                model: selectedModel,
                apiURL: currentURL!,
                providerName: selectedProvider,
                systemPrompt: effectiveSystemPrompt,
                customAPIFormat: customAPIFormat
            )
            
            guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIError.invalidResponse
            }
            
            aiConnectionTestSucceeded = true
            aiConnectionTestMessage = "AI connection test passed"
            refreshAIConfigurationStatus()
        } catch let error as AIError {
            let message = error.errorDescription ?? "AI connection test failed"
            aiConnectionTestSucceeded = false
            aiConnectionTestMessage = message
            markAIUnavailable("AI unavailable: \(message)")
        } catch {
            aiConnectionTestSucceeded = false
            aiConnectionTestMessage = error.localizedDescription
            markAIUnavailable("AI unavailable: \(error.localizedDescription)")
        }
    }
    
    func organize(input: String) async -> String? {
        let validation = validateAISetup()
        
        guard validation.isValid else {
            errorMessage = validation.message
            markAIUnavailable(compactConfigurationMessage())
            return nil
        }
        
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "No content to organize. Please paste or add some text first."
            return nil
        }
        
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        let startTime = Date()
        
        do {
            let result = try await client.organize(
                input: input,
                apiKey: apiKey,
                model: selectedModel,
                apiURL: currentURL!,
                providerName: selectedProvider,
                systemPrompt: effectiveSystemPrompt,
                customAPIFormat: customAPIFormat
            )
            
            lastLatency = Date().timeIntervalSince(startTime)
            
            return result
        } catch let error as AIError {
            let message = error.errorDescription ?? "Unknown error"
            errorMessage = "❌ AI Processing Error:\n\n\(message)"
            markAIUnavailable("AI unavailable: \(message)")
            return nil
        } catch {
            errorMessage = "❌ AI Processing Error:\n\n\(error.localizedDescription)"
            markAIUnavailable("AI unavailable: \(error.localizedDescription)")
            return nil
        }
    }
}
