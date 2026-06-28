import SwiftUI
import AppKit
import Vision
import CoreImage

struct CapturePanel: View {
    @Binding var capturedContent: String
    @Binding var hasPendingProcessing: Bool
    @Binding var capturedAttachments: [CapturedAttachment]
    @Binding var inputWordCount: Int
    let language: String
    @State private var droppedItems: [DraggedItem] = []
    @State private var processedDroppedItemIDs: Set<UUID> = []
    @State private var captureItems: [CaptureWorkspaceItem] = []
    @State private var manualText: String = ""
    
    let pasteTextNotification = NotificationCenter.default.publisher(for: NSNotification.Name("PasteTextItem"))
    let pasteImageNotification = NotificationCenter.default.publisher(for: NSNotification.Name("PasteImageItem"))
    private let extractor = ContentExtractor()
    
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            DropZone(droppedItems: $droppedItems, language: language)
                .frame(height: 130)
            
            CaptureWorkspace(captureItems: $captureItems, language: language)
                .frame(maxHeight: .infinity)
            
            Divider()
            
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    AppSectionHeader(title: t("Paste or Type Text", "粘贴或输入文本"), systemImage: "doc.text")
                    Spacer()
                    if !manualText.isEmpty {
                        IconButton(systemImage: "xmark", action: { manualText = "" }, help: t("Clear text", "清空文本"))
                    }
                }
                
                SubmitTextEditor(
                    text: $manualText,
                    onSubmit: addManualTextItem
                )
                    .appTextSurface(minHeight: 80, maxHeight: 120)
                
                if !manualText.isEmpty {
                    SecondaryButton(
                        label: t("Add as Item", "添加为项目"),
                        systemImage: "plus.circle.fill",
                        action: addManualTextItem,
                        isFullWidth: true,
                        tint: AppColors.paste
                    )
                }
            }
            .appSurface(.muted)
        }
        .padding(AppSpacing.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .onChange(of: droppedItems) { _ in
            processNewDrops()
        }
        .onChange(of: captureItems.count) { _ in
            publishCaptureState()
        }
        .onChange(of: captureItems.map(\.ocrText)) { _ in
            publishCaptureState()
        }
        .onChange(of: captureItems.map(\.status)) { _ in
            publishCaptureState()
        }
        .onChange(of: manualText) { _ in
            updateInputWordCount()
        }
        .onReceive(pasteTextNotification) { notification in
            if let pastedText = notification.object as? String {
                addPastedTextItem(pastedText)
            }
        }
        .onReceive(pasteImageNotification) { notification in
            if let imageURL = notification.object as? URL {
                addPastedImageItem(imageURL)
            }
        }
    }
    
    private func addPastedImageItem(_ imageURL: URL) {
        var workspaceItem = CaptureWorkspaceItem(
            id: UUID(),
            name: imageURL.lastPathComponent,
            type: .image,
            sourceURL: imageURL,
            thumbnail: NSImage(contentsOf: imageURL)
        )
        workspaceItem.status = .waiting
        captureItems.append(workspaceItem)
        
        // Start OCR processing
        if let index = captureItems.firstIndex(where: { $0.id == workspaceItem.id }) {
            // Update status to processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if index < captureItems.count {
                    captureItems[index].status = .processing
                }
            }
            
            Task {
                let extracted = await extractor.extract(from: imageURL)
                await MainActor.run {
                    updateItem(id: workspaceItem.id, text: extracted, status: .completed)
                }
            }
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
    
    private func addPastedTextItem(_ text: String) {
        if addURLItemsIfNeeded(from: text, fallbackName: t("Pasted Link", "粘贴的链接")) {
            return
        }

        let newItem = CaptureWorkspaceItem(
            id: UUID(),
            name: t("Pasted Text", "粘贴文本"),
            type: .text,
            sourceURL: nil,
            thumbnail: nil
        )
        var item = newItem
        item.ocrText = text
        item.status = .completed
        captureItems.insert(item, at: 0)
    }
    
    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string) {
            manualText = text
        }
    }
    
    private func processNewDrops() {
        // Remove items marked for deletion
        captureItems.removeAll { $0.isRemoved }
        
        let existingIds = Set(captureItems.map { $0.id })
        let newItems = droppedItems.filter {
            !existingIds.contains($0.id) && !processedDroppedItemIDs.contains($0.id)
        }
        
        for item in newItems {
            processedDroppedItemIDs.insert(item.id)

            let workspaceItem = CaptureWorkspaceItem(
                id: item.id,
                name: item.name,
                type: determineCaptureType(item.type),
                sourceURL: item.url,
                thumbnail: item.url.flatMap { NSImage(contentsOf: $0) }
            )
            
            captureItems.append(workspaceItem)
            
            if let textContent = item.textContent {
                updateItem(id: item.id, text: textContent, status: .completed)
            } else if workspaceItem.type == .image && item.url != nil {
                if let index = captureItems.firstIndex(where: { $0.id == item.id }) {
                    // Update status to processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if index < captureItems.count {
                            captureItems[index].status = .processing
                        }
                    }
                    
                    if let imageURL = item.url {
                        Task {
                            let extracted = await extractor.extract(from: imageURL)
                            await MainActor.run {
                                updateItem(id: item.id, text: extracted, status: .completed)
                            }
                        }
                    }
                }
            } else if let fileURL = item.url {
                updateItem(id: item.id, text: "", status: .processing)
                Task {
                    let extracted = await extractor.extract(from: fileURL)
                    await MainActor.run {
                        updateItem(id: item.id, text: extracted, status: .completed)
                    }
                }
            } else {
                updateItem(
                    id: item.id,
                    text: "Could not read dropped text content from the drag provider.",
                    status: .failed
                )
            }
        }
        publishCaptureState()
    }
    
    private func addManualTextItem() {
        if addURLItemsIfNeeded(from: manualText, fallbackName: t("Manual Link", "手动链接")) {
            manualText = ""
            publishCaptureState()
            return
        }

        let newItem = CaptureWorkspaceItem(
            id: UUID(),
            name: t("Manual Text", "手动文本"),
            type: .text,
            sourceURL: nil,
            thumbnail: nil
        )
        var item = newItem
        item.ocrText = manualText
        item.status = .completed
        captureItems.insert(item, at: 0)
        manualText = ""
        publishCaptureState()
    }

    private func addURLItemsIfNeeded(from text: String, fallbackName: String) -> Bool {
        let urls = extractURLs(from: text)
        guard !urls.isEmpty else { return false }

        let noteText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for url in urls {
            let itemID = UUID()
            var item = CaptureWorkspaceItem(
                id: itemID,
                name: readableName(for: url, fallbackName: fallbackName),
                type: .url,
                sourceURL: nil,
                thumbnail: nil
            )
            item.ocrText = """
            URL: \(url.absoluteString)
            Source platform: \(platformName(for: url))
            \(noteText == url.absoluteString ? "" : "\nUser note:\n\(noteText)")
            """
            item.status = .processing
            captureItems.insert(item, at: 0)

            Task {
                let extracted = await extractor.extract(fromWebURL: url)
                await MainActor.run {
                    let existingText = captureItems.first(where: { $0.id == itemID })?.ocrText ?? ""
                    updateItem(
                        id: itemID,
                        text: mergeURLMetadata(existingText, fetchedText: extracted),
                        status: .completed
                    )
                }
            }
        }

        return true
    }

    private func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var urls: [URL] = []
        var seen = Set<String>()

        detector.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            guard let url = result?.url,
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  seen.insert(url.absoluteString).inserted else {
                return
            }
            urls.append(url)
        }

        return urls
    }

    private func mergeURLMetadata(_ existingText: String, fetchedText: String) -> String {
        let fetched = fetchedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fetched.isEmpty else { return existingText }

        return """
        \(existingText)

        Fetched content:
        \(fetched)
        """
    }

    private func readableName(for url: URL, fallbackName: String) -> String {
        if let host = url.host, !host.isEmpty {
            return host
        }
        return fallbackName
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
    
    private func publishCaptureState() {
        capturedContent = captureItems
            .filter { !$0.ocrText.isEmpty }
            .map { item in
                """
                Source: \(item.name)
                Type: \(item.type)
                
                \(item.ocrText)
                """
            }
            .joined(separator: "\n\n---\n\n")

        capturedAttachments = captureItems.compactMap { item in
            guard let sourceURL = item.sourceURL else { return nil }

            let kind: CapturedAttachment.Kind
            switch item.type {
            case .image:
                kind = .image
            case .pdf, .officeDocument:
                kind = .document
            case .text, .url, .file:
                return nil
            }

            return CapturedAttachment(
                id: item.id,
                name: item.name,
                sourceURL: sourceURL,
                kind: kind
            )
        }
        
        hasPendingProcessing = captureItems.contains { item in
            item.status == .waiting || item.status == .processing
        }

        updateInputWordCount()
    }

    private func updateInputWordCount() {
        let itemText = captureItems
            .map(\.ocrText)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let draftText = manualText.trimmingCharacters(in: .whitespacesAndNewlines)

        inputWordCount = [itemText, draftText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .wordCount
    }
    
    private func updateItem(id: UUID, text: String, status: StatusBadge.Status) {
        guard let index = captureItems.firstIndex(where: { $0.id == id }) else { return }
        captureItems[index].ocrText = text
        captureItems[index].status = status
        publishCaptureState()
    }
    
    private func determineCaptureType(_ type: String) -> CaptureItemType {
        switch type.uppercased() {
        case "PDF": return .pdf
        case "DOC", "DOCX", "XLS", "XLSX", "PPT", "PPTX": return .officeDocument
        case "JPG", "JPEG", "PNG", "HEIC", "GIF", "TIFF": return .image
        case "TXT", "MD", "MARKDOWN": return .text
        case "URL": return .url
        default: return .file
        }
    }
}
