import SwiftUI
import Foundation

@MainActor
final class PreviewViewModel: ObservableObject {
    @Published var markdown = ""
    @Published var title = ""
    @Published var tags: [String] = []
    @Published var isEditing = false
    @Published var error: String?
    
    init() {}
    
    @MainActor
    func generateMarkdown(from content: String) async {
        do {
            let builder = MarkdownBuilder()
            markdown = try await builder.build(content: content)
        } catch {
            self.error = error.localizedDescription
            markdown = ""
        }
    }
    
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    func reset() {
        markdown = ""
        title = ""
        tags.removeAll()
        isEditing = false
        error = nil
    }
}

// MARK: - Markdown Builder

class MarkdownBuilder {
    func build(content: String) async throws -> String {
        let frontmatter = """
        ---
        created: \(ISO8601DateFormatter().string(from: Date()))
        ---
        
        """
        
        return frontmatter + content
    }
}
