import Foundation

final class ObsidianWriter {
    func save(
        markdown: String,
        vaultPath: String,
        folderName: String,
        attachments: [CapturedAttachment] = [],
        usesOutputSubfolder: Bool = true,
        storesAttachmentsInSubfolder: Bool = true
    ) throws -> URL {
        let vault = URL(fileURLWithPath: (vaultPath as NSString).expandingTildeInPath)
        let cleanFolderName = folderName.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let folder = usesOutputSubfolder && !cleanFolderName.isEmpty
            ? vault.appendingPathComponent(cleanFolderName)
            : vault
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // If markdown contains absolute image links (file:// or /absolute/path), copy those files into the note folder and rewrite links to the local filename
        var updated = markdown
        do {
            let pattern = "!\\[[^\\]]*\\]\\((file://[^)]+|/[^)]+)\\)"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsrange = NSRange(updated.startIndex..., in: updated)
            let matches = regex.matches(in: updated, options: [], range: nsrange)
            // Process in reverse so ranges remain valid
            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                let wholeRange = match.range(at: 0)
                let pathRange = match.range(at: 1)
                if let pathR = Range(pathRange, in: updated), let wholeR = Range(wholeRange, in: updated) {
                    var pathStr = String(updated[pathR])
                    if pathStr.hasPrefix("file://") { pathStr = String(pathStr.dropFirst("file://".count)) }
                    let srcURL = URL(fileURLWithPath: pathStr)
                    var filename = sanitizeFilename(srcURL.lastPathComponent)
                    var destURL = folder.appendingPathComponent(filename)
                    var unique = 1
                    while FileManager.default.fileExists(atPath: destURL.path) {
                        let base = srcURL.deletingPathExtension().lastPathComponent
                        let ext = srcURL.pathExtension
                        filename = "\(base)-\(unique).\(ext)"
                        destURL = folder.appendingPathComponent(filename)
                        unique += 1
                    }
                    do { try FileManager.default.copyItem(at: srcURL, to: destURL) } catch { /* ignore copy errors */ }
                    let replacement = "![](\(filename))"
                    updated.replaceSubrange(wholeR, with: replacement)
                }
            }
        } catch {
            // if regex fails for any reason, fall back to original markdown
        }

        updated = try appendCapturedAttachments(
            attachments,
            to: updated,
            noteFolder: folder,
            storesAttachmentsInSubfolder: storesAttachmentsInSubfolder
        )

        let title = extractTitle(from: updated)
        let filename = "\(timestamp())-\(sanitizeFilename(title)).md"
        let url = folder.appendingPathComponent(filename)
        try updated.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func fallbackMarkdown(from input: String) -> String {
        let now = displayDate()
        let title = deriveTitle(from: input)
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceType = deriveSourceType(from: input)

        if isPrimarilyEnglish(input) {
            return """
            ---
            created: \(now)
            source_type: \(sourceType)
            tags:
              - inbox
              - unprocessed
            status: unreviewed
            ---

            # \(title)

            ## Summary

            This is an original captured item that has not been organized by AI yet.

            ## Organized Notes

            To be organized.

            ## Original Input

            ```text
            \(trimmedInput)
            ```
            """
        }

        return """
        ---
        created: \(now)
        source_type: \(sourceType)
        tags:
          - inbox
          - 待整理
        status: unreviewed
        ---

        # \(title)

        ## 摘要

        这是一条尚未经过 GPT 整理的原始收集内容。

        ## 整理内容

        待整理。

        ## 原始内容

        ```text
        \(trimmedInput)
        ```
        """
    }

    private func appendCapturedAttachments(
        _ attachments: [CapturedAttachment],
        to markdown: String,
        noteFolder: URL,
        storesAttachmentsInSubfolder: Bool
    ) throws -> String {
        guard !attachments.isEmpty else { return markdown }

        let attachmentFolderName = storesAttachmentsInSubfolder ? "attachments" : ""
        let attachmentFolder = storesAttachmentsInSubfolder
            ? noteFolder.appendingPathComponent(attachmentFolderName, isDirectory: true)
            : noteFolder
        try FileManager.default.createDirectory(at: attachmentFolder, withIntermediateDirectories: true)

        var lines: [String] = []
        var copiedSourcePaths = Set<String>()

        for attachment in attachments where copiedSourcePaths.insert(attachment.sourceURL.path).inserted {
            let copiedName = try copyAttachment(attachment, to: attachmentFolder)
            let linkTarget = storesAttachmentsInSubfolder ? "\(attachmentFolderName)/\(copiedName)" : copiedName
            switch attachment.kind {
            case .image:
                lines.append("![](\(linkTarget))")
            case .document:
                lines.append("- [\(copiedName)](\(linkTarget))")
            }
        }

        guard !lines.isEmpty else { return markdown }

        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentHeading = isPrimarilyEnglish(trimmed) ? "Attachments" : "附件"
        return """
        \(trimmed)

        ## \(attachmentHeading)

        \(lines.joined(separator: "\n"))
        """
    }

    private func copyAttachment(_ attachment: CapturedAttachment, to folder: URL) throws -> String {
        let sourceURL = attachment.sourceURL
        let originalName = attachment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? sourceURL.lastPathComponent
            : attachment.name
        let sanitizedOriginalName = sanitizeFilename(originalName)
        let baseName = URL(fileURLWithPath: sanitizedOriginalName).deletingPathExtension().lastPathComponent
        let sourceExtension = sourceURL.pathExtension.isEmpty
            ? URL(fileURLWithPath: sanitizedOriginalName).pathExtension
            : sourceURL.pathExtension
        let fileExtension = sourceExtension.isEmpty ? "png" : sourceExtension

        var filename = "\(sanitizeFilename(baseName)).\(fileExtension)"
        var destinationURL = folder.appendingPathComponent(filename)
        var unique = 1

        while FileManager.default.fileExists(atPath: destinationURL.path) {
            filename = "\(sanitizeFilename(baseName))-\(unique).\(fileExtension)"
            destinationURL = folder.appendingPathComponent(filename)
            unique += 1
        }

        if sourceURL.standardizedFileURL.path != destinationURL.standardizedFileURL.path {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        return filename
    }

    private func extractTitle(from markdown: String) -> String {
        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return deriveTitle(from: markdown)
    }

    private func deriveTitle(from text: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallbackUntitledName(for: text)

        if firstLine.count <= 28 {
            return firstLine
        }
        return String(firstLine.prefix(28))
    }

    private func sanitizeFilename(_ title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = title
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled Capture" : cleaned
    }

    private func isPrimarilyEnglish(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let cjkCount = scalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count
        let latinCount = scalars.filter { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) || (0x0061...0x007A).contains(Int(scalar.value))
        }.count

        return latinCount > 0 && latinCount >= cjkCount
    }

    private func fallbackUntitledName(for text: String) -> String {
        isPrimarilyEnglish(text) ? "Untitled Capture" : "未命名收集"
    }

    private func deriveSourceType(from input: String) -> String {
        let lowercased = input.lowercased()
        var types = Set<String>()

        if lowercased.contains("type: image") {
            types.insert("image")
        }
        if lowercased.contains("type: pdf") {
            types.insert("pdf")
        }
        if lowercased.contains("type: officedocument")
            || lowercased.contains("type: office_document")
            || lowercased.contains(".docx")
            || lowercased.contains(".xlsx")
            || lowercased.contains(".pptx") {
            types.insert("office_document")
        }
        if lowercased.contains("type: web_url")
            || lowercased.contains("type: url")
            || lowercased.contains("type: captureitemtype.url")
            || lowercased.contains("url: http") {
            types.insert("web_url")
        }
        if lowercased.contains("type: file") {
            types.insert("file")
        }
        if lowercased.contains("type: text") || lowercased.contains("manual text") || lowercased.contains("pasted text") {
            types.insert("manual")
        }

        if types.count > 1 {
            return "mixed"
        }

        return types.first ?? "manual"
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private func displayDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
