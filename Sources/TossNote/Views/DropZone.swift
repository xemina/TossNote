import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DropZone: View {
    @Binding var droppedItems: [DraggedItem]
    let language: String
    @State private var isTargeted = false
    @State private var showImportHelp = false
    
    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(isTargeted ? AppColors.activeStrong : AppColors.secondary)
            
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(t("Drop Files Here", "将文件拖到这里"))
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)

                    Button(action: { showImportHelp.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(t("Supported formats and extraction rules", "支持的格式和提取规则"))
                    .popover(isPresented: $showImportHelp, arrowEdge: .bottom) {
                        ImportHelpPopover(language: language)
                    }
                }
                
                Text(t("Images, PDFs, Office docs, text, Markdown, CSV, JSON, HTML, XML, or RTF", "支持图片、PDF、Office 文档、文本、Markdown、CSV、JSON、HTML、XML、RTF"))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
            }
            
            SecondaryButton(
                label: t("Choose Files", "选择文件"),
                systemImage: "folder",
                action: chooseFiles,
                tint: AppColors.paste,
                fill: AppColors.pasteFill
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(isTargeted ? AppColors.dropBackground.opacity(0.9) : AppColors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                )
                .foregroundStyle(isTargeted ? AppColors.activeStrong : AppColors.subtleBorder)
        )
        .onDrop(of: [.fileURL, .pdf, .image, .plainText, .data], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            // For file URLs (from Finder)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString) {
                        DispatchQueue.main.async { appendFile(url) }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async { appendFile(url) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                loadDataBackedFile(from: provider, type: .pdf, fallbackName: "Dropped PDF.pdf")
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                loadImageBackedFile(from: provider)
            } else if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let text = item as? String {
                        let textContent = text
                        DispatchQueue.main.async {
                            droppedItems.append(
                                DraggedItem(name: t("Dropped Text", "拖入文本"), type: "TEXT", url: nil, textContent: textContent)
                            )
                        }
                    } else if let text = item as? NSString {
                        let textContent = String(text)
                        DispatchQueue.main.async {
                            droppedItems.append(
                                DraggedItem(name: t("Dropped Text", "拖入文本"), type: "TEXT", url: nil, textContent: textContent)
                            )
                        }
                    }
                }
            }
        }
    }

    private func loadDataBackedFile(from provider: NSItemProvider, type: UTType, fallbackName: String) {
        provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
            guard let data,
                  let tempURL = writeTemporaryInboxFile(data: data, fallbackName: fallbackName) else {
                return
            }

            DispatchQueue.main.async { appendFile(tempURL) }
        }
    }

    private func loadImageBackedFile(from provider: NSItemProvider) {
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data,
                  let tempURL = writeTemporaryInboxFile(data: data, fallbackName: "Dropped Image.png") else {
                return
            }

            DispatchQueue.main.async { appendFile(tempURL) }
        }
    }
    
    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = t("Choose Files", "选择文件")
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [
            .image,
            .pdf,
            .plainText,
            .text,
            .html,
            .xml,
            .json,
            .commaSeparatedText,
            .rtf,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "xls") ?? .data,
            UTType(filenameExtension: "xlsx") ?? .data,
            UTType(filenameExtension: "ppt") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data,
            UTType(filenameExtension: "log") ?? .plainText,
            UTType(filenameExtension: "yaml") ?? .plainText,
            UTType(filenameExtension: "yml") ?? .plainText,
            UTType(filenameExtension: "md") ?? .plainText
        ]
        
        if panel.runModal() == .OK {
            panel.urls.forEach(appendFile)
        }
    }
    
    private func appendFile(_ url: URL) {
        droppedItems.append(
            DraggedItem(
                name: url.lastPathComponent,
                type: url.pathExtension.uppercased(),
                url: url
            )
        )
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

private struct ImportHelpPopover: View {
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: t("Import Rules", "导入规则"), systemImage: "info.circle")

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HelpLine(title: t("Images", "图片"), detail: t("PNG, JPG, JPEG, HEIC, GIF, TIFF, BMP, WEBP. Local OCR runs up to 20 MB.", "PNG、JPG、JPEG、HEIC、GIF、TIFF、BMP、WEBP。本地 OCR 最多处理 20 MB。"))
                HelpLine(title: t("PDF", "PDF"), detail: t("Extracts selectable text only. Reads up to 50 pages and 60,000 characters.", "只提取可选择文本。最多读取 50 页和 60,000 个字符。"))
                HelpLine(title: t("Office", "Office"), detail: t("DOCX, XLSX, PPTX get basic text extraction. DOC, XLS, PPT are best effort. Files over 25 MB are attached only.", "DOCX、XLSX、PPTX 支持基础文本提取。DOC、XLS、PPT 尽力处理。超过 25 MB 只作为附件保存。"))
                HelpLine(title: t("Text", "文本"), detail: t("TXT, MD, LOG, YAML, CSV, JSON, HTML, XML, RTF. Text files over 5 MB are skipped.", "TXT、MD、LOG、YAML、CSV、JSON、HTML、XML、RTF。超过 5 MB 的文本文件会跳过。"))
                HelpLine(title: t("Links", "链接"), detail: t("Pasted URLs are saved and fetched locally when possible. Some platforms may block extraction.", "粘贴的 URL 会保存，并尽可能在本地抓取内容。部分平台可能阻止提取。"))
                HelpLine(title: t("Attachments", "附件"), detail: t("Images and documents are copied to Obsidian attachments when saving.", "保存时会把图片和文档复制到 Obsidian 附件目录。"))
            }
        }
        .padding(AppSpacing.large)
        .frame(width: 380)
        .background(AppColors.surfaceRaised)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

private struct HelpLine: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.primary)
            Text(detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func writeTemporaryInboxFile(data: Data, fallbackName: String) -> URL? {
    let destinationURL = temporaryInboxURL(for: fallbackName)

    do {
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    } catch {
        return nil
    }
}

private func temporaryInboxURL(for filename: String) -> URL {
    let sanitized = filename
        .components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:"))
        .joined(separator: "-")
    let name = sanitized.isEmpty ? "Dropped File" : sanitized
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TossNoteDrops", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    return directory
        .appendingPathComponent("\(UUID().uuidString)-\(name)")
}

struct DraggedItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: String
    let url: URL?
    let textContent: String?
    
    init(id: UUID = UUID(), name: String, type: String, url: URL?, textContent: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.textContent = textContent
    }
    
    static func == (lhs: DraggedItem, rhs: DraggedItem) -> Bool {
        lhs.id == rhs.id
    }
}
