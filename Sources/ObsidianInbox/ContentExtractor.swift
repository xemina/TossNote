import AppKit
import PDFKit
import UniformTypeIdentifiers
@preconcurrency import Vision

final class ContentExtractor: @unchecked Sendable {
    private let maxPDFPages = 50
    private let maxExtractedCharacters = 60_000
    private let maxTextFileBytes = 5 * 1024 * 1024
    private let maxImageBytes = 20 * 1024 * 1024
    private let maxOfficeFileBytes = 25 * 1024 * 1024
    private let maxWebResponseBytes = 8 * 1024 * 1024

    func extract(from url: URL) async -> String {
        let didAccessScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let ext = url.pathExtension.lowercased()
        let fileSize = fileSizeBytes(for: url)

        if ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp"].contains(ext),
           let image = NSImage(contentsOf: url) {
            if let fileSize, fileSize > maxImageBytes {
                return """
                Image OCR skipped because the image is \(formatBytes(fileSize)), which is larger than the \(formatBytes(maxImageBytes)) local OCR limit.
                """
            }

            // Do not include the file path as the content, only the OCR/classification result.
            let text = await extract(from: image)
            return sourceBlock("image", url: url, content: text)
        }

        if ext == "pdf" {
            let text = extractPDF(from: url)
            return sourceBlock("pdf", url: url, content: text)
        }

        if ["doc", "docx", "xls", "xlsx", "ppt", "pptx"].contains(ext) {
            let text = extractOfficeDocument(from: url, ext: ext, fileSize: fileSize)
            return sourceBlock("office", url: url, content: text)
        }

        if ["rtf", "rtfd"].contains(ext), let fileSize, fileSize > maxTextFileBytes {
            return """
            Text extraction skipped because this file is \(formatBytes(fileSize)), which is larger than the \(formatBytes(maxTextFileBytes)) local text file limit.
            """
        }

        if ["rtf", "rtfd"].contains(ext), let text = extractAttributedText(from: url) {
            return sourceBlock("rtf", url: url, content: limitedContent(text, sourceName: url.lastPathComponent))
        }

        if ["txt", "md", "markdown", "csv", "json", "html", "htm", "xml", "log", "yaml", "yml"].contains(ext),
           let fileSize,
           fileSize > maxTextFileBytes {
            return """
            Text extraction skipped because this file is \(formatBytes(fileSize)), which is larger than the \(formatBytes(maxTextFileBytes)) local text file limit.
            """
        }

        if ["txt", "md", "markdown", "csv", "json", "html", "htm", "xml", "log", "yaml", "yml"].contains(ext),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return sourceBlock(
                "file",
                url: url,
                content: limitedContent(cleanHTMLIfNeeded(text, ext: ext), sourceName: url.lastPathComponent)
            )
        }

        if let fileSize, fileSize > maxTextFileBytes {
            return """
            Text extraction skipped because this file is \(formatBytes(fileSize)), which is larger than the \(formatBytes(maxTextFileBytes)) local text file limit.
            """
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return sourceBlock("file", url: url, content: limitedContent(text, sourceName: url.lastPathComponent))
        }

        return sourceBlock("file", url: url, content: "Could not extract text from this file.")
    }

    func extract(fromWebURL url: URL) async -> String {
        let platform = platformName(for: url)

        do {
            let request = webRequest(for: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            return """
            \(formatWebExtractionResult(
                data: data,
                originalURL: url,
                resolvedURL: httpResponse?.url ?? url,
                platform: platform,
                statusCode: httpResponse?.statusCode,
                contentType: httpResponse?.value(forHTTPHeaderField: "Content-Type")
            ))
            """
        } catch {
            return """
            Source: \(url.absoluteString)
            Type: web_url
            Platform: \(platform)

            Could not fetch this URL: \(error.localizedDescription)
            """
        }
    }

    private func webRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,text/plain;q=0.8,*/*;q=0.5",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        return request
    }

    private func formatWebExtractionResult(
        data: Data,
        originalURL: URL,
        resolvedURL: URL,
        platform: String,
        statusCode: Int?,
        contentType: String?
    ) -> String {
        let statusLine = statusCode.map(String.init) ?? "unknown"

        guard data.count <= maxWebResponseBytes else {
            return """
            Source: \(originalURL.absoluteString)
            Resolved URL: \(resolvedURL.absoluteString)
            Type: web_url
            Platform: \(platform)
            Fetch status: skipped_response_too_large
            HTTP status: \(statusLine)

            The response was \(formatBytes(data.count)), which is larger than the \(formatBytes(maxWebResponseBytes)) local web extraction limit. The link has been saved for review.
            """
        }

        guard let html = decodeWebData(data, contentType: contentType),
              !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return """
            Source: \(originalURL.absoluteString)
            Resolved URL: \(resolvedURL.absoluteString)
            Type: web_url
            Platform: \(platform)
            Fetch status: failed_to_decode_response
            HTTP status: \(statusLine)

            The link has been saved, but the response could not be decoded as readable text.
            """
        }

        let article = WebArticleExtractor().extract(html: html, url: resolvedURL)
        let limitedArticleText = limitedContent(article.contentText, sourceName: originalURL.absoluteString)
        let platformNote = platformRestrictionNote(for: originalURL)

        return """
        Source: \(originalURL.absoluteString)
        Resolved URL: \(resolvedURL.absoluteString)
        Type: web_url
        Platform: \(platform)
        Fetch status: \(article.extractionStatus)
        HTTP status: \(statusLine)
        Title: \(article.title ?? "Unknown")
        Site: \(article.siteName ?? "Unknown")
        Author: \(article.author ?? "Unknown")
        Published: \(article.publishedAt ?? "Unknown")
        Excerpt: \(article.excerpt ?? "None")
        \(platformNote)

        Extracted content:
        \(limitedArticleText)
        """
    }

    private func decodeWebData(_ data: Data, contentType: String?) -> String? {
        if let contentType,
           let charset = contentType
            .components(separatedBy: ";")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { $0.lowercased().hasPrefix("charset=") })?
            .dropFirst("charset=".count)
            .lowercased(),
           let encoding = stringEncoding(for: String(charset)),
           let text = String(data: data, encoding: encoding) {
            return text
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(data: data, encoding: .ascii)
    }

    private func stringEncoding(for charset: String) -> String.Encoding? {
        switch charset {
        case "utf-8", "utf8":
            return .utf8
        case "iso-8859-1", "latin1":
            return .isoLatin1
        case "us-ascii", "ascii":
            return .ascii
        case "gbk", "gb2312", "gb18030":
            return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        case "big5":
            return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        default:
            return nil
        }
    }

    private func platformRestrictionNote(for url: URL) -> String {
        guard requiresManualReview(url) else { return "" }
        return "Platform note: This platform often restricts direct extraction. If the extracted content is incomplete, keep the link and add copied page text manually."
    }

    func extract(from image: NSImage) async -> String {
        guard let cgImage = image.cgImageForVision else {
            return "Could not read this image."
        }
        // First attempt OCR
        let ocrText = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(returning: "")
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let preferredLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            if let supportedLanguages = try? request.supportedRecognitionLanguages() {
                let availableLanguages = preferredLanguages.filter { supportedLanguages.contains($0) }
                request.recognitionLanguages = availableLanguages.isEmpty ? preferredLanguages : availableLanguages
            } else {
                request.recognitionLanguages = preferredLanguages
            }
            request.minimumTextHeight = 0.01

            let handler = VNImageRequestHandler(cgImage: cgImage)
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch { continuation.resume(returning: "") }
            }
        }

        if !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ocrText
        }

        // If OCR found nothing, attempt to classify the image to produce tags
        let tags = await classify(image: cgImage)
        let tagsLine = tags.isEmpty ? "" : "Tags: " + tags.joined(separator: ", ") + "\n\n"
        // We no longer need to reference the image file path in the content returned by the extractor.
        // The ContentView will manage the image display via InputImageItem.
        return tagsLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeImageToTemp(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else { return nil }
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = "obsidian_img_\(UUID().uuidString).png"
        let url = tempDir.appendingPathComponent(filename)
        do { try data.write(to: url); return url } catch { return nil }
    }

    // Classify image using Vision's built-in classifier (returns top labels)
    func classify(image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let _ = error { continuation.resume(returning: []) ; return }
                let results = request.results as? [VNClassificationObservation] ?? []
                let labels = results.prefix(3).map { $0.identifier }
                continuation.resume(returning: Array(labels))
            }

            let handler = VNImageRequestHandler(cgImage: image)
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch { continuation.resume(returning: []) }
            }
        }
    }

    private func extractPDF(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else {
            return "Could not open PDF."
        }

        var pages: [String] = []
        let totalPages = document.pageCount
        let pagesToRead = min(totalPages, maxPDFPages)
        var didHitCharacterLimit = false

        for index in 0..<pagesToRead {
            if let page = document.page(at: index), let text = page.string {
                pages.append(text)
                if pages.joined(separator: "\n\n").count >= maxExtractedCharacters {
                    didHitCharacterLimit = true
                    break
                }
            }
        }

        let extracted = pages.joined(separator: "\n\n")
        let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return """
            No selectable text was found in this PDF. Scanned PDFs are not OCR processed automatically to avoid slow extraction and oversized AI prompts.
            """
        }

        let limited = limitedContent(trimmed, sourceName: url.lastPathComponent)

        var notes: [String] = []
        if totalPages > pagesToRead {
            notes.append("PDF extraction read the first \(pagesToRead) of \(totalPages) pages.")
        }
        if didHitCharacterLimit || trimmed.count > maxExtractedCharacters {
            notes.append("Extracted text was limited to \(maxExtractedCharacters) characters.")
        }

        if notes.isEmpty {
            return limited
        }

        return """
        Extraction notes:
        \(notes.map { "- \($0)" }.joined(separator: "\n"))

        \(limited)
        """
    }

    private func extractAttributedText(from url: URL) -> String? {
        guard let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else {
            return nil
        }
        return attributed.string
    }

    private func extractOfficeDocument(from url: URL, ext: String, fileSize: Int?) -> String {
        if let fileSize, fileSize > maxOfficeFileBytes {
            return """
            Office document attached but text extraction was skipped because this file is \(formatBytes(fileSize)), which is larger than the \(formatBytes(maxOfficeFileBytes)) Office extraction limit.
            """
        }

        let extracted: String?
        switch ext {
        case "docx":
            extracted = extractDocx(from: url)
        case "xlsx":
            extracted = extractXlsx(from: url)
        case "pptx":
            extracted = extractPptx(from: url)
        case "doc", "xls", "ppt":
            extracted = extractAttributedText(from: url)
        default:
            extracted = nil
        }

        guard let extracted,
              !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return """
            Office document attached. Text extraction is not available for this file, so AI can only use the filename and surrounding input context.
            """
        }

        return limitedContent(extracted, sourceName: url.lastPathComponent)
    }

    private func extractDocx(from url: URL) -> String? {
        guard let xml = unzipEntry("word/document.xml", from: url) else {
            return nil
        }
        return textFromXML(xml)
    }

    private func extractPptx(from url: URL) -> String? {
        let slideEntries = unzipEntryNames(from: url)
            .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        guard !slideEntries.isEmpty else { return nil }

        let slides = slideEntries.enumerated().compactMap { index, entry -> String? in
            guard let xml = unzipEntry(entry, from: url) else { return nil }
            let text = textFromXML(xml).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return "Slide \(index + 1)\n\(text)"
        }

        return slides.joined(separator: "\n\n")
    }

    private func extractXlsx(from url: URL) -> String? {
        let entries = unzipEntryNames(from: url)
        var sections: [String] = []

        if let sharedStringsXML = unzipEntry("xl/sharedStrings.xml", from: url) {
            let sharedStrings = textFromXML(sharedStringsXML)
            if !sharedStrings.isEmpty {
                sections.append("Shared strings\n\(sharedStrings)")
            }
        }

        let sheetEntries = entries
            .filter { $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        for (index, entry) in sheetEntries.enumerated() {
            guard let xml = unzipEntry(entry, from: url) else { continue }
            let sheetText = textFromXML(xml).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sheetText.isEmpty else { continue }
            sections.append("Sheet \(index + 1)\n\(sheetText)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func unzipEntryNames(from url: URL) -> [String] {
        guard let output = runUnzip(arguments: ["-Z1", url.path]) else {
            return []
        }

        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func unzipEntry(_ entry: String, from url: URL) -> String? {
        runUnzip(arguments: ["-p", url.path, entry])
    }

    private func runUnzip(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func textFromXML(_ xml: String) -> String {
        var text = xml
        text = text.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: "\n", options: .regularExpression)
        text = decodeXMLEntities(text)

        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func decodeXMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    private func sourceBlock(_ type: String, url: URL, content: String) -> String {
        // We are no longer displaying the file path directly in the input area.
        // The ContentView will display the thumbnail and OCR result.
        return content
    }

    // This function is no longer needed as we are not embedding image links in the extracted text.
    // The ContentView will manage image display via InputImageItem.
    // private func replaceFirstImageLink(in text: String, with url: URL) -> String {
    //     return text
    // }

    private func cleanHTMLIfNeeded(_ text: String, ext: String) -> String {
        guard ["html", "htm"].contains(ext) else { return text }

        var output = text
        output = output.replacingOccurrences(of: #"(?is)<script.*?</script>"#, with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(?is)<style.*?</style>"#, with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: #"&nbsp;"#, with: " ")
        output = output.replacingOccurrences(of: #"&amp;"#, with: "&")
        output = output.replacingOccurrences(of: #"&lt;"#, with: "<")
        output = output.replacingOccurrences(of: #"&gt;"#, with: ">")
        output = output.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func limitedContent(_ text: String, sourceName: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxExtractedCharacters else {
            return trimmed
        }

        let limited = String(trimmed.prefix(maxExtractedCharacters))
        return """
        Extraction notes:
        - \(sourceName) was truncated to the first \(maxExtractedCharacters) characters before sending to AI.

        \(limited)
        """
    }

    private func fileSizeBytes(for url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func requiresManualReview(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("youtube.com")
            || host.contains("youtu.be")
            || host.contains("xiaohongshu.com")
            || host.contains("xhslink.com")
            || host.contains("mp.weixin.qq.com")
    }

    private func platformName(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""

        if host.contains("youtube.com") || host.contains("youtu.be") {
            return "YouTube"
        }
        if host.contains("xiaohongshu.com") || host.contains("xhslink.com") {
            return "Xiaohongshu"
        }
        if host.contains("mp.weixin.qq.com") {
            return "WeChat Official Account"
        }

        return host.isEmpty ? "Web" : host
    }
}

private extension NSImage {
    var cgImageForVision: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
