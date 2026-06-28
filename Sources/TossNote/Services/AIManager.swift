import Foundation

// MARK: - Protocol-Based Architecture

protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var defaultURL: String { get }
    var models: [String] { get }
    var defaultModel: String { get }
    
    func buildRequest(
        input: String,
        apiKey: String,
        model: String,
        apiURL: URL,
        systemPrompt: String
    ) async throws -> URLRequest
    
    func parseResponse(data: Data) throws -> String
    func parseError(statusCode: Int, data: Data) throws -> Never
}

enum CustomAPIFormat: String, CaseIterable, Identifiable {
    case openAIChatCompletions = "OpenAI Chat Completions"
    case anthropicMessages = "Anthropic Messages"

    var id: String { rawValue }
}

// MARK: - Error Handling

enum AIError: LocalizedError {
    case invalidAPIKey
    case quotaExceeded(String)
    case rateLimited(String)
    case invalidEndpoint
    case connectionTimeout
    case networkUnavailable
    case jsonDecodingFailed(String)
    case serverError(Int, String)
    case invalidResponse
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .quotaExceeded(let msg):
            return "API quota exceeded. Please check your account limits.\n\nDetails: \(msg)"
        case .rateLimited(let msg):
            return "Rate limited. Too many requests. Please try again later.\n\nDetails: \(msg)"
        case .invalidEndpoint:
            return "Invalid API endpoint. Please verify the URL."
        case .connectionTimeout:
            return "Connection timeout. Please check your network."
        case .networkUnavailable:
            return "Network unavailable."
        case .jsonDecodingFailed(let msg):
            return "Failed to parse API response: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .invalidResponse:
            return "Received invalid response from API."
        case .unknown(let msg):
            return "Unknown error: \(msg)"
        }
    }
}

// MARK: - OpenAI Compatible Provider

final class OpenAICompatibleProvider: AIProviderProtocol {
    let name: String
    let defaultURL: String
    let models: [String]
    let defaultModel: String
    
    init(
        name: String,
        defaultURL: String,
        models: [String],
        defaultModel: String
    ) {
        self.name = name
        self.defaultURL = defaultURL
        self.models = models
        self.defaultModel = defaultModel
    }
    
    func buildRequest(
        input: String,
        apiKey: String,
        model: String,
        apiURL: URL,
        systemPrompt: String
    ) async throws -> URLRequest {
        let today = ISO8601DateFormatter().string(from: Date())
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": """
            Current date: \(today)
            
            Convert the following captured input into one Obsidian Markdown note.
            
            <raw_input>
            \(input)
            </raw_input>
            """]
        ]
        
        var body: [String: Any] = [
            "messages": messages,
            "temperature": 0.2
        ]
        
        if !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["model"] = model
        }
        
        var request = URLRequest(url: normalizedChatCompletionsURL(from: apiURL))
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }

    private func normalizedChatCompletionsURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if trimmedPath.hasSuffix("chat/completions") {
            return url
        }

        if trimmedPath.isEmpty {
            components.path = "/v1/chat/completions"
        } else {
            components.path = "/" + trimmedPath + "/chat/completions"
        }

        return components.url ?? url
    }
    
    func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.jsonDecodingFailed("Invalid JSON structure")
        }
        
        if let choices = json["choices"] as? [[String: Any]] {
            for choice in choices {
                if let message = choice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        if let outputText = json["output_text"] as? String {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let output = json["output"] as? [[String: Any]] {
            var pieces: [String] = []
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for contentItem in content {
                        if let text = contentItem["text"] as? String {
                            pieces.append(text)
                        } else if let text = contentItem["output_text"] as? String {
                            pieces.append(text)
                        }
                    }
                }
            }
            return pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw AIError.invalidResponse
    }
    
    func parseError(statusCode: Int, data: Data) throws -> Never {
        let message = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
        
        if statusCode == 401 || message.contains("unauthorized") || message.contains("invalid_api_key") {
            throw AIError.invalidAPIKey
        }
        
        if statusCode == 429 || message.contains("quota") || message.contains("rate_limit") {
            throw AIError.quotaExceeded(message)
        }
        
        if statusCode == 404 {
            throw AIError.serverError(
                statusCode,
                """
                \(message)

                Endpoint not found. For Custom/OpenAI-compatible APIs, use a base URL ending in /v1 or the full /v1/chat/completions endpoint, and verify the exact model ID.
                """
            )
        }

        throw AIError.serverError(statusCode, message)
    }
    
    static let defaultSystemPrompt = """
    You are an Obsidian inbox note organizer. Your job is to transform captured input into one clean Markdown note for storage, review, linking, and future retrieval.
    
    Core rules:
    - Output only the final Markdown note. Do not add explanations before or after it.
    - Do not invent facts. If the input is unclear, keep uncertainty explicit.
    - Preserve all important information from the input.
    - Preserve the original input at the end of the note without summarizing or deleting it.
    - Use the same primary language as the input for all visible note text, including headings, labels, summaries, tags, and task text.
    - If the input is primarily English, the entire Markdown note must be English. Do not use Chinese section headings or Chinese labels.
    - If the input is primarily Chinese, use Chinese for the Markdown note. If the input is mixed, prefer the user's main language.
    - Use Obsidian-friendly Markdown and valid YAML frontmatter.
    
    Required YAML frontmatter:
    ---
    created: current date from the user message
    source_type: choose one of manual, image, pdf, office_document, web_url, file, or mixed based on the captured sources
    status: unreviewed
    tags:
      - concise-topic-tag
    related:
      - optional-related-keyword
    ---
    
    Title rule:
    - The note must start with exactly one H1 title line.
    - By default, use a concise descriptive title inferred from the input.
    - If a custom title format is provided later in this prompt, follow that custom format instead.
    
    Required Markdown structure:
    # A concise descriptive title
    
    ## Summary
    2-5 bullet points summarizing the captured input.
    
    ## Tags and Links
    - Topics: concise topic labels or keywords
    - People/Projects/Places/Dates: include only items present in the input
    - Related keywords: terms useful for future Obsidian search or linking
    
    ## Organized Notes
    Organize the input into readable sections, lists, or tables when useful. Keep details that may matter later.
    
    ## Action Items
    Include this section only if the input contains tasks, questions, decisions, or follow-up items.
    
    ## Original Input
    Include the original captured input verbatim in a fenced text block. Do not omit, rewrite, or truncate it.

    For Chinese input, translate the section headings and labels naturally:
    - Summary -> 摘要
    - Tags and Links -> 标签与关联
    - Topics -> 主题
    - People/Projects/Places/Dates -> 人物/项目/地点/时间
    - Related keywords -> 可关联关键词
    - Organized Notes -> 整理内容
    - Action Items -> 待处理
    - Original Input -> 原文
    
    Formatting constraints:
    - Do not wrap the entire response in a code fence.
    - A fenced text block is allowed only inside the Original Input / 原文 section.
    - Tags must be concise, without the leading # character.
    - Prefer 3-8 tags. Use English tags for English input and Chinese tags for Chinese input.
    - Keep status as unreviewed by default because a captured note still needs human review after saving.
    - Use source_type: mixed when there are multiple meaningful source types in the input.
    """
}

// MARK: - Anthropic Compatible Provider

final class AnthropicCompatibleProvider: AIProviderProtocol {
    let name: String
    let defaultURL: String
    let models: [String]
    let defaultModel: String

    init(
        name: String,
        defaultURL: String,
        models: [String],
        defaultModel: String
    ) {
        self.name = name
        self.defaultURL = defaultURL
        self.models = models
        self.defaultModel = defaultModel
    }

    func buildRequest(
        input: String,
        apiKey: String,
        model: String,
        apiURL: URL,
        systemPrompt: String
    ) async throws -> URLRequest {
        let today = ISO8601DateFormatter().string(from: Date())
        let userPrompt = """
        Current date: \(today)

        Convert the following captured input into one Obsidian Markdown note.

        <raw_input>
        \(input)
        </raw_input>
        """

        var body: [String: Any] = [
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ]
        ]

        if !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["model"] = model
        }

        var request = URLRequest(url: normalizedMessagesURL(from: apiURL))
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }

    private func normalizedMessagesURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if trimmedPath.hasSuffix("messages") {
            return url
        }

        if trimmedPath.isEmpty {
            components.path = "/v1/messages"
        } else {
            components.path = "/" + trimmedPath + "/messages"
        }

        return components.url ?? url
    }

    func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.jsonDecodingFailed("Invalid JSON structure")
        }

        if let content = json["content"] as? [[String: Any]] {
            let pieces = content.compactMap { item in
                item["text"] as? String
            }
            let text = pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }

        if let completion = json["completion"] as? String {
            return completion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw AIError.invalidResponse
    }

    func parseError(statusCode: Int, data: Data) throws -> Never {
        let message = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"

        if statusCode == 401 || message.contains("authentication_error") || message.contains("invalid_api_key") {
            throw AIError.invalidAPIKey
        }

        if statusCode == 429 || message.contains("rate_limit") || message.contains("quota") {
            throw AIError.quotaExceeded(message)
        }

        if statusCode == 404 {
            throw AIError.serverError(
                statusCode,
                """
                \(message)

                Endpoint not found. For Custom/Anthropic-compatible APIs, use a base URL ending in /v1 or the full /v1/messages endpoint, and verify the exact model ID.
                """
            )
        }

        throw AIError.serverError(statusCode, message)
    }
}

// MARK: - Google Gemini Provider

final class GoogleGeminiProvider: AIProviderProtocol {
    let name = "Google Gemini"
    let defaultURL = "https://generativelanguage.googleapis.com/v1beta/models"
    let models = ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite"]
    let defaultModel = "gemini-2.5-flash"
    
    func buildRequest(
        input: String,
        apiKey: String,
        model: String,
        apiURL: URL,
        systemPrompt: String
    ) async throws -> URLRequest {
        let today = ISO8601DateFormatter().string(from: Date())
        let fullPrompt = """
        \(systemPrompt)
        
        Current date: \(today)
        
        Convert the following captured input into one Obsidian Markdown note.
        
        <raw_input>
        \(input)
        </raw_input>
        """
        
        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : model
        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent"
        
        guard let url = URL(string: baseURL) else {
            throw AIError.invalidEndpoint
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let finalURL = components?.url else {
            throw AIError.invalidEndpoint
        }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": fullPrompt]]]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.jsonDecodingFailed("Invalid JSON structure")
        }
        
        guard let candidates = json["candidates"] as? [[String: Any]] else {
            if let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                throw AIError.unknown(msg)
            }
            throw AIError.invalidResponse
        }
        
        var pieces: [String] = []
        for candidate in candidates {
            if let content = candidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        pieces.append(text)
                    }
                }
            }
        }
        
        return pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parseError(statusCode: Int, data: Data) throws -> Never {
        let message = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
        
        if statusCode == 401 {
            throw AIError.invalidAPIKey
        }
        
        if statusCode == 429 || message.contains("RESOURCE_EXHAUSTED") || message.contains("quota") {
            throw AIError.quotaExceeded(message)
        }
        
        throw AIError.serverError(statusCode, message)
    }
}

// MARK: - Provider Registry

final class AIProviderRegistry: @unchecked Sendable {
    static let shared = AIProviderRegistry()
    
    private var providers: [String: AIProviderProtocol] = [:]
    private let lock = NSLock()
    
    init() {
        registerDefaultProviders()
    }
    
    private func registerDefaultProviders() {
        // OpenAI
        register(
            "OpenAI",
            provider: OpenAICompatibleProvider(
                name: "OpenAI",
                defaultURL: "https://api.openai.com/v1/chat/completions",
                models: ["gpt-5", "gpt-5-mini", "gpt-4.1", "gpt-4.1-mini", "o4-mini"],
                defaultModel: "gpt-5"
            )
        )
        
        // DeepSeek
        register(
            "DeepSeek",
            provider: OpenAICompatibleProvider(
                name: "DeepSeek",
                defaultURL: "https://api.deepseek.com/chat/completions",
                models: ["deepseek-chat", "deepseek-reasoner"],
                defaultModel: "deepseek-chat"
            )
        )
        
        // Google Gemini
        register(
            "Google Gemini",
            provider: GoogleGeminiProvider()
        )
        
        // OpenRouter (OpenAI-compatible)
        register(
            "OpenRouter",
            provider: OpenAICompatibleProvider(
                name: "OpenRouter",
                defaultURL: "https://openrouter.ai/api/v1/chat/completions",
                models: [],
                defaultModel: "openai/gpt-4o-mini"
            )
        )
        
        // AnyRouter (OpenAI-compatible)
        register(
            "AnyRouter",
            provider: OpenAICompatibleProvider(
                name: "AnyRouter",
                defaultURL: "https://anyrouter.top/v1/chat/completions",
                models: [],
                defaultModel: "gpt-4o-mini"
            )
        )
    }
    
    func register(_ key: String, provider: AIProviderProtocol) {
        lock.lock()
        defer { lock.unlock() }
        providers[key] = provider
    }
    
    func provider(for key: String) -> AIProviderProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return providers[key]
    }
    
    func allProviderNames() -> [String] {
        ["OpenAI", "DeepSeek", "Google Gemini", "OpenRouter", "AnyRouter", "Custom"]
    }
}
