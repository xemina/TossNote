import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DropZone: View {
    @Binding var droppedItems: [DraggedItem]
    @State private var isTargeted = false
    @State private var showImportHelp = false
    
    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(isTargeted ? AppColors.active : AppColors.secondary)
            
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Text("Drop Files Here")
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)

                    Button(action: { showImportHelp.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Supported formats and extraction rules")
                    .popover(isPresented: $showImportHelp, arrowEdge: .bottom) {
                        ImportHelpPopover()
                    }
                }
                
                Text("Images, PDFs, Office docs, text, Markdown, CSV, JSON, HTML, XML, or RTF")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
            }
            
            SecondaryButton(
                label: "Choose Files",
                systemImage: "folder",
                action: chooseFiles
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
                .foregroundStyle(isTargeted ? AppColors.active : AppColors.subtleBorder)
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
                                DraggedItem(name: "Dropped Text", type: "TEXT", url: nil, textContent: textContent)
                            )
                        }
                    } else if let text = item as? NSString {
                        let textContent = String(text)
                        DispatchQueue.main.async {
                            droppedItems.append(
                                DraggedItem(name: "Dropped Text", type: "TEXT", url: nil, textContent: textContent)
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
}

private struct ImportHelpPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "Import Rules", systemImage: "info.circle")

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HelpLine(title: "Images", detail: "PNG, JPG, JPEG, HEIC, GIF, TIFF, BMP, WEBP. Local OCR runs up to 20 MB.")
                HelpLine(title: "PDF", detail: "Extracts selectable text only. Reads up to 50 pages and 60,000 characters.")
                HelpLine(title: "Office", detail: "DOCX, XLSX, PPTX get basic text extraction. DOC, XLS, PPT are best effort. Files over 25 MB are attached only.")
                HelpLine(title: "Text", detail: "TXT, MD, LOG, YAML, CSV, JSON, HTML, XML, RTF. Text files over 5 MB are skipped.")
                HelpLine(title: "Links", detail: "Pasted URLs are saved and fetched locally when possible. Some platforms may block extraction.")
                HelpLine(title: "Attachments", detail: "Images and documents are copied to Obsidian attachments when saving.")
            }
        }
        .padding(AppSpacing.large)
        .frame(width: 380)
        .background(AppColors.surfaceRaised)
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
        .appendingPathComponent("ObsidianInboxDrops", isDirectory: true)
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
