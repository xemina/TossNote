import SwiftUI

struct PreviewPanel: View {
    @Binding var markdown: String
    
    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(title: "Markdown", systemImage: "doc.text.image")
            .padding(AppSpacing.medium)
            
            Divider()
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $markdown)
                    .font(AppTypography.monospace)
                    .appTextSurface(minHeight: nil, maxHeight: nil)
                    .padding(AppSpacing.panelPadding)

                if markdown.isEmpty {
                    Text("Markdown will appear here")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.tertiary)
                        .padding(AppSpacing.panelPadding + AppSpacing.medium)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

struct MarkdownView: View {
    let text: String
    
    var body: some View {
        if text.isEmpty {
            AppEmptyState(systemImage: "doc.text", title: "Markdown will appear here")
        } else {
            MarkdownRenderer(text: text)
        }
    }
}

struct MarkdownRenderer: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            ForEach(parseMarkdownElements(text), id: \.self) { element in
                renderElement(element)
            }
        }
        .textSelection(.enabled)
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            Text(text)
                .font(AppTypography.body)
        case .codeBlock(let code):
            CodeBlockView(code: code)
        case .list(let items):
            renderList(items)
        case .link(let text, let url):
            Link(text, destination: URL(string: url) ?? URL(fileURLWithPath: ""))
                .foregroundStyle(AppColors.active)
        case .task(let completed, let text):
            HStack(spacing: AppSpacing.small) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completed ? AppColors.success : AppColors.secondary)
                Text(text)
                    .font(AppTypography.body)
                    .strikethrough(completed)
            }
        }
    }
    
    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        let size: CGFloat = level == 1 ? 24 : level == 2 ? 20 : level == 3 ? 18 : 16
        Text(text)
            .font(.system(size: size, weight: .bold))
            .padding(.top, AppSpacing.medium)
    }
    
    @ViewBuilder
    private func renderList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: AppSpacing.small) {
                    Text("•")
                        .font(AppTypography.body)
                    Text(item)
                        .font(AppTypography.body)
                }
            }
        }
    }
}

struct CodeBlockView: View {
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(code)
                .font(AppTypography.monospace)
                .foregroundStyle(AppColors.secondary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(AppSpacing.medium)
        }
        .appSurface(.muted, padding: 0, radius: AppRadius.medium)
    }
}

enum MarkdownElement: Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case codeBlock(String)
    case list([String])
    case link(text: String, url: String)
    case task(completed: Bool, text: String)
}

func parseMarkdownElements(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    var currentText = ""
    
    let lines = text.components(separatedBy: .newlines)
    var i = 0
    
    while i < lines.count {
        let line = lines[i]
        
        // Headings
        if line.starts(with: "# ") {
            elements.append(.heading(level: 1, text: String(line.dropFirst(2))))
        } else if line.starts(with: "## ") {
            elements.append(.heading(level: 2, text: String(line.dropFirst(3))))
        } else if line.starts(with: "### ") {
            elements.append(.heading(level: 3, text: String(line.dropFirst(4))))
        }
        // Tasks
        else if line.starts(with: "- [x] ") {
            elements.append(.task(completed: true, text: String(line.dropFirst(6))))
        } else if line.starts(with: "- [ ] ") {
            elements.append(.task(completed: false, text: String(line.dropFirst(6))))
        }
        // Code blocks
        else if line.starts(with: "```") {
            i += 1
            var codeLines: [String] = []
            while i < lines.count && !lines[i].starts(with: "```") {
                codeLines.append(lines[i])
                i += 1
            }
            elements.append(.codeBlock(codeLines.joined(separator: "\n")))
        }
        // List items
        else if line.starts(with: "- ") {
            var listItems: [String] = []
            while i < lines.count && lines[i].starts(with: "- ") {
                listItems.append(String(lines[i].dropFirst(2)))
                i += 1
            }
            elements.append(.list(listItems))
            i -= 1
        }
        // Paragraphs
        else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
            currentText = line
            // Look for inline links
            if currentText.contains("[") && currentText.contains("](") {
                // Simple link extraction
                if let start = currentText.firstIndex(of: "["),
                   let middle = currentText[currentText.index(after: start)...].firstIndex(of: "]"),
                   let urlStart = currentText[middle...].firstIndex(of: "("),
                   let urlEnd = currentText[currentText.index(after: urlStart)...].firstIndex(of: ")") {
                    let linkText = String(currentText[currentText.index(after: start)..<middle])
                    let urlText = String(currentText[currentText.index(after: urlStart)..<urlEnd])
                    elements.append(.link(text: linkText, url: urlText))
                } else {
                    elements.append(.paragraph(currentText))
                }
            } else {
                elements.append(.paragraph(currentText))
            }
        }
        
        i += 1
    }
    
    return elements
}
