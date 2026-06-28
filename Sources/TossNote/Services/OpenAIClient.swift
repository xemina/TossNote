import Foundation

// MARK: - AI Client using Provider Architecture

final class OpenAIClient: @unchecked Sendable {
    private let registry = AIProviderRegistry.shared
    
    func organize(
        input: String,
        apiKey: String,
        model: String,
        apiURL: URL,
        providerName: String,
        systemPrompt: String = OpenAICompatibleProvider.defaultSystemPrompt,
        customAPIFormat: CustomAPIFormat = .openAIChatCompletions
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.invalidAPIKey
        }
        
        let provider: AIProviderProtocol
        
        if providerName == "Custom" {
            switch customAPIFormat {
            case .openAIChatCompletions:
                provider = OpenAICompatibleProvider(
                    name: "Custom",
                    defaultURL: apiURL.absoluteString,
                    models: [],
                    defaultModel: model
                )
            case .anthropicMessages:
                provider = AnthropicCompatibleProvider(
                    name: "Custom",
                    defaultURL: apiURL.absoluteString,
                    models: [],
                    defaultModel: model
                )
            }
        } else if let registeredProvider = registry.provider(for: providerName) {
            provider = registeredProvider
        } else {
            throw AIError.unknown("Unknown provider: \(providerName)")
        }
        
        let request = try await provider.buildRequest(
            input: input,
            apiKey: apiKey,
            model: model,
            apiURL: apiURL,
            systemPrompt: systemPrompt
        )
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            // Handle errors
            if !(200..<300).contains(httpResponse.statusCode) {
                try provider.parseError(statusCode: httpResponse.statusCode, data: data)
            }
            
            let markdown = try provider.parseResponse(data: data)
            return markdown
        } catch let error as AIError {
            throw error
        } catch let error as NSError {
            if error.domain == NSURLErrorDomain {
                if error.code == NSURLErrorTimedOut {
                    throw AIError.connectionTimeout
                } else if error.code == NSURLErrorNotConnectedToInternet {
                    throw AIError.networkUnavailable
                }
            }
            throw AIError.unknown(error.localizedDescription)
        }
    }
    
    // Backward compatibility method
    func organize(input: String, apiKey: String, model: String, apiURL: URL, provider: AIProviderType = .openAI) async throws -> String {
        let providerName: String
        switch provider {
        case .openAI:
            providerName = "OpenAI"
        case .deepseek:
            providerName = "DeepSeek"
        case .openRouter:
            providerName = "OpenRouter"
        case .google:
            providerName = "Google Gemini"
        case .custom:
            providerName = "Custom"
        }
        
        return try await organize(
            input: input,
            apiKey: apiKey,
            model: model,
            apiURL: apiURL,
            providerName: providerName
        )
    }
}

// MARK: - Legacy Provider Type (for backward compatibility)

enum AIProviderType: String {
    case openAI
    case deepseek
    case openRouter
    case google
    case custom
}
