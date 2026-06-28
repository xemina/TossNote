import SwiftUI

// MARK: - View Extensions

extension View {
    func allPadding(_ padding: CGFloat) -> some View {
        self.padding(padding)
    }
    
    func horizontalPadding(_ padding: CGFloat) -> some View {
        self.padding(.horizontal, padding)
    }
    
    func verticalPadding(_ padding: CGFloat) -> some View {
        self.padding(.vertical, padding)
    }
}

// MARK: - String Extensions

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var wordCount: Int {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        var latinWordCount = 0
        var cjkCharacterCount = 0
        var isInsideLatinWord = false

        for scalar in trimmed.unicodeScalars {
            let value = scalar.value
            let isCJK = (0x4E00...0x9FFF).contains(Int(value))
                || (0x3400...0x4DBF).contains(Int(value))
                || (0x3040...0x30FF).contains(Int(value))
                || (0xAC00...0xD7AF).contains(Int(value))
            let isLatinLetterOrDigit = !isCJK && CharacterSet.alphanumerics.contains(scalar)

            if isLatinLetterOrDigit {
                if !isInsideLatinWord {
                    latinWordCount += 1
                    isInsideLatinWord = true
                }
            } else {
                isInsideLatinWord = false
            }

            if isCJK {
                cjkCharacterCount += 1
            }
        }

        return latinWordCount + cjkCharacterCount
    }
    
    func truncated(to length: Int) -> String {
        if count > length {
            return String(prefix(length)) + "..."
        }
        return self
    }
}

// MARK: - Color Extensions

extension Color {
    static let panelBackground = Color(nsColor: .textBackgroundColor)
    static let controlBackground = Color(nsColor: .controlBackgroundColor)
}

// MARK: - Array Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - Date Extensions

extension Date {
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var isoString: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    func createDirectoryIfNeeded(at url: URL) throws {
        if !fileExists(atPath: url.path) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.size] as? Int64
    }
}

// MARK: - Binding Extensions
