import Foundation

struct JoplinSavedNote {
    let id: String
    let title: String
}

final class JoplinWriter: @unchecked Sendable {
    func save(
        markdown: String,
        port: String,
        token: String,
        notebookName: String,
        attachments: [CapturedAttachment] = []
    ) async throws -> JoplinSavedNote {
        let baseURL = try baseURL(port: port)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw JoplinError.missingToken }

        let folderID = try await findOrCreateFolder(
            named: notebookName.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL,
            token: trimmedToken
        )
        let body = try await appendResources(
            attachments,
            to: markdown,
            baseURL: baseURL,
            token: trimmedToken
        )
        let title = extractTitle(from: body)
        let noteID = try await createNote(
            title: title,
            body: body,
            parentID: folderID,
            baseURL: baseURL,
            token: trimmedToken
        )

        return JoplinSavedNote(id: noteID, title: title)
    }

    private func baseURL(port: String) throws -> URL {
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let portNumber = Int(trimmedPort), portNumber > 0,
              let url = URL(string: "http://127.0.0.1:\(portNumber)") else {
            throw JoplinError.invalidPort
        }
        return url
    }

    private func findOrCreateFolder(named name: String, baseURL: URL, token: String) async throws -> String? {
        guard !name.isEmpty else { return nil }

        let foldersURL = try apiURL(baseURL: baseURL, path: "/folders", token: token, queryItems: [
            URLQueryItem(name: "fields", value: "id,title")
        ])
        let data = try await sendJSONRequest(url: foldersURL, method: "GET")
        let response = try JSONDecoder().decode(JoplinListResponse<JoplinFolder>.self, from: data)

        if let existing = response.items.first(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing.id
        }

        let createURL = try apiURL(baseURL: baseURL, path: "/folders", token: token)
        let createData = try await sendJSONRequest(
            url: createURL,
            method: "POST",
            body: ["title": name]
        )
        let created = try JSONDecoder().decode(JoplinFolder.self, from: createData)
        return created.id
    }

    private func appendResources(
        _ attachments: [CapturedAttachment],
        to markdown: String,
        baseURL: URL,
        token: String
    ) async throws -> String {
        guard !attachments.isEmpty else { return markdown }

        var lines: [String] = []
        var uploadedPaths = Set<String>()

        for attachment in attachments where uploadedPaths.insert(attachment.sourceURL.path).inserted {
            let resource = try await uploadResource(attachment, baseURL: baseURL, token: token)
            switch attachment.kind {
            case .image:
                lines.append("![\(resource.title)](:/\(resource.id))")
            case .document:
                lines.append("- [\(resource.title)](:/\(resource.id))")
            }
        }

        guard !lines.isEmpty else { return markdown }

        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = isPrimarilyEnglish(trimmed) ? "Attachments" : "附件"
        return """
        \(trimmed)

        ## \(heading)

        \(lines.joined(separator: "\n"))
        """
    }

    private func uploadResource(
        _ attachment: CapturedAttachment,
        baseURL: URL,
        token: String
    ) async throws -> JoplinResource {
        let url = try apiURL(baseURL: baseURL, path: "/resources", token: token)
        let boundary = "Boundary-\(UUID().uuidString)"
        let filename = attachment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? attachment.sourceURL.lastPathComponent
            : attachment.name
        let didAccessScopedResource = attachment.sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessScopedResource {
                attachment.sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        let fileData = try Data(contentsOf: attachment.sourceURL)
        let props = #"{"title":"\#(escapeJSON(filename))"}"#

        var body = Data()
        body.appendMultipartField(name: "props", value: props, boundary: boundary)
        body.appendMultipartFile(
            name: "data",
            filename: filename,
            contentType: contentType(for: attachment.sourceURL),
            data: fileData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await send(request)
        return try JSONDecoder().decode(JoplinResource.self, from: data)
    }

    private func createNote(
        title: String,
        body: String,
        parentID: String?,
        baseURL: URL,
        token: String
    ) async throws -> String {
        let url = try apiURL(baseURL: baseURL, path: "/notes", token: token)
        var payload: [String: Any] = [
            "title": title,
            "body": body
        ]
        if let parentID {
            payload["parent_id"] = parentID
        }

        let data = try await sendJSONRequest(url: url, method: "POST", body: payload)
        let note = try JSONDecoder().decode(JoplinNote.self, from: data)
        return note.id
    }

    private func apiURL(
        baseURL: URL,
        path: String,
        token: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false)
        var items = queryItems
        items.append(URLQueryItem(name: "token", value: token))
        components?.queryItems = items

        guard let url = components?.url else {
            throw JoplinError.invalidURL
        }
        return url
    }

    private func sendJSONRequest(
        url: URL,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw JoplinError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw JoplinError.server(httpResponse.statusCode, message)
            }
            return data
        } catch let error as JoplinError {
            throw error
        } catch {
            throw JoplinError.connection(error.localizedDescription)
        }
    }

    private func extractTitle(from markdown: String) -> String {
        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return sanitizeTitle(String(trimmed.dropFirst(2)))
            }
        }
        return sanitizeTitle(markdown.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? "Untitled Capture")
    }

    private func sanitizeTitle(_ title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return cleaned.isEmpty ? "Untitled Capture" : String(cleaned.prefix(80))
    }

    private func isPrimarilyEnglish(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let cjkCount = scalars.filter { (0x4E00...0x9FFF).contains(Int($0.value)) }.count
        let latinCount = scalars.filter {
            (0x0041...0x005A).contains(Int($0.value)) || (0x0061...0x007A).contains(Int($0.value))
        }.count
        return latinCount > 0 && latinCount >= cjkCount
    }

    private func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default: return "application/octet-stream"
        }
    }

    private func escapeJSON(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum JoplinError: LocalizedError {
    case missingToken
    case invalidPort
    case invalidURL
    case invalidResponse
    case connection(String)
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Joplin API token is missing. Enable Web Clipper in Joplin and paste the token in Settings > Storage."
        case .invalidPort:
            return "Joplin port is invalid. The default Web Clipper port is 41184."
        case .invalidURL:
            return "Joplin API URL is invalid."
        case .invalidResponse:
            return "Joplin returned an invalid response."
        case .connection(let message):
            return "Could not connect to Joplin Web Clipper. Make sure Joplin is running and Web Clipper is enabled. Details: \(message)"
        case .server(let code, let message):
            return "Joplin API error (\(code)): \(message)"
        }
    }
}

private struct JoplinListResponse<T: Decodable>: Decodable {
    let items: [T]
}

private struct JoplinFolder: Decodable {
    let id: String
    let title: String
}

private struct JoplinNote: Decodable {
    let id: String
}

private struct JoplinResource: Decodable {
    let id: String
    let title: String
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(contentType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }
}
