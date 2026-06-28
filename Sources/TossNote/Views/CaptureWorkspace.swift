import SwiftUI
import AppKit

struct CaptureWorkspace: View {
    @Binding var captureItems: [CaptureWorkspaceItem]
    let language: String
    @State private var expandedItems: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            if captureItems.isEmpty {
                AppEmptyState(systemImage: "inbox", title: t("No items captured", "还没有添加项目"))
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.medium) {
                        ForEach($captureItems) { $item in
                            if item.type == .text {
                                TextItemView(
                                    item: $item,
                                    language: language,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            } else if item.type == .url {
                                URLItemView(
                                    item: $item,
                                    language: language,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            } else if item.type == .image {
                                ImageItemView(
                                    item: $item,
                                    language: language,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            } else {
                                DocumentItemView(
                                    item: $item,
                                    language: language,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            }
                        }
                    }
                    .padding(AppSpacing.medium)
                }
            }
        }
        .appSurface(.raised, padding: 0)
    }
    
    private func removeItem(_ id: UUID) {
        captureItems.removeAll { $0.id == id }
        expandedItems.remove(id)
    }
    
    private func toggleExpanded(_ id: UUID) {
        if expandedItems.contains(id) {
            expandedItems.remove(id)
        } else {
            expandedItems.insert(id)
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

// MARK: - Document Item View
struct DocumentItemView: View {
    @Binding var item: CaptureWorkspaceItem
    let language: String
    var isExpanded: Bool
    var toggleExpanded: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Image(systemName: item.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.name)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(documentSubtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(status: item.status, label: item.statusLabel(language: language))
                IconButton(systemImage: "xmark", action: onRemove, help: t("Remove this document", "移除此文档"))
            }

            if !item.ocrText.isEmpty {
                if isExpanded {
                    TextEditor(text: $item.ocrText)
                        .appTextSurface(minHeight: 100, maxHeight: 220)
                } else {
                    Text(summaryText)
                        .font(AppTypography.caption)
                        .lineLimit(5)
                        .foregroundStyle(AppColors.primary)
                        .padding(AppSpacing.small)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .appSurface(.raised, padding: AppSpacing.small, radius: AppRadius.medium)
                }

                if item.ocrText.split(separator: "\n").count > 5 {
                    Button(action: toggleExpanded) {
                        HStack(spacing: AppSpacing.xs) {
                            Text(isExpanded ? t("Show Less", "收起") : t("Show More", "展开"))
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.activeStrong)
                    }
                    .buttonStyle(.plain)
                }
            } else if item.status == .failed {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.warning)
                    Text(t("Could not extract content.", "无法提取内容。"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            } else if item.status == .processing || item.status == .waiting {
                HStack(spacing: AppSpacing.small) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(t("Extracting document text...", "正在提取文档文本..."))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
        }
        .appSurface(.muted)
    }

    private var documentSubtitle: String {
        switch item.type {
        case .pdf:
            return t("PDF document", "PDF 文档")
        case .officeDocument:
            return t("Office document", "Office 文档")
        case .file:
            return t("File", "文件")
        case .image:
            return t("Image", "图片")
        case .url:
            return t("Link", "链接")
        case .text:
            return t("Text", "文本")
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .pdf:
            return AppColors.error
        case .officeDocument:
            return AppColors.activeStrong
        default:
            return AppColors.secondary
        }
    }

    private var summaryText: String {
        item.ocrText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(8)
            .joined(separator: "\n")
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

// MARK: - URL Item View
struct URLItemView: View {
    @Binding var item: CaptureWorkspaceItem
    let language: String
    var isExpanded: Bool
    var toggleExpanded: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.activeStrong)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.name)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)

                    if let urlLine {
                        Text(urlLine)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                StatusBadge(status: item.status, label: item.statusLabel(language: language))
                IconButton(systemImage: "xmark", action: onRemove, help: t("Remove this link", "移除此链接"))
            }

            if !item.ocrText.isEmpty {
                if isExpanded {
                    TextEditor(text: $item.ocrText)
                        .appTextSurface(minHeight: 100, maxHeight: 220)
                } else {
                    Text(summaryText)
                        .font(AppTypography.caption)
                        .lineLimit(4)
                        .foregroundStyle(AppColors.primary)
                        .padding(AppSpacing.small)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .appSurface(.raised, padding: AppSpacing.small, radius: AppRadius.medium)
                }

                if item.ocrText.split(separator: "\n").count > 4 {
                    Button(action: toggleExpanded) {
                        HStack(spacing: AppSpacing.xs) {
                            Text(isExpanded ? t("Show Less", "收起") : t("Show More", "展开"))
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.activeStrong)
                    }
                    .buttonStyle(.plain)
                }
            } else if item.status == .processing || item.status == .waiting {
                HStack(spacing: AppSpacing.small) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(t("Fetching link content...", "正在抓取链接内容..."))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
        }
        .appSurface(.muted)
    }

    private var urlLine: String? {
        item.ocrText
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix("URL: ") }
            .map { String($0.dropFirst("URL: ".count)) }
    }

    private var summaryText: String {
        let lines = item.ocrText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !$0.hasPrefix("URL: ") }
            .filter { !$0.hasPrefix("Source platform:") }

        return lines.prefix(8).joined(separator: "\n")
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

// MARK: - Text Item View (Simple, no image)
struct TextItemView: View {
    @Binding var item: CaptureWorkspaceItem
    let language: String
    var isExpanded: Bool
    var toggleExpanded: () -> Void
    var onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            // Header with title and remove button
            HStack(spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.name)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                
                Spacer()
                
                IconButton(systemImage: "xmark", action: onRemove, help: t("Remove this item", "移除此项目"))
            }
            
            // Text content
            if isExpanded {
                // Full text - editable
                TextEditor(text: $item.ocrText)
                    .appTextSurface(minHeight: 100, maxHeight: 200)
            } else {
                // Collapsed - first few lines
                let lines = item.ocrText.split(separator: "\n", maxSplits: 4, omittingEmptySubsequences: false).prefix(4)
                Text(lines.joined(separator: "\n"))
                    .font(AppTypography.body)
                    .lineLimit(4)
                    .foregroundStyle(AppColors.primary)
                    .padding(AppSpacing.small)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .appSurface(.raised, padding: AppSpacing.small, radius: AppRadius.medium)
            }
            
            // Expand button
            if item.ocrText.split(separator: "\n").count > 4 {
                Button(action: toggleExpanded) {
                    HStack {
                        Spacer()
                        Text(isExpanded ? t("Show Less", "收起") : t("Show More", "展开"))
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(AppColors.activeStrong)
                }
                .buttonStyle(.plain)
            }
        }
        .appSurface(.muted)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

// MARK: - Image Item View
struct ImageItemView: View {
    @Binding var item: CaptureWorkspaceItem
    let language: String
    var isExpanded: Bool
    var toggleExpanded: () -> Void
    var onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            // Image and Metadata Side-by-Side
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                // Thumbnail - LEFT SIDE
                Group {
                    if let thumbnail = item.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipped()
                            .cornerRadius(AppRadius.small)
                    } else {
                        Image(systemName: item.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.secondary)
                            .frame(width: 120, height: 120)
                            .background(AppColors.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                }
                
                // Metadata and OCR Results - RIGHT SIDE
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    // Header with metadata
                    HStack(spacing: AppSpacing.small) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(item.name)
                                .font(AppTypography.bodyMedium)
                                .lineLimit(2)
                            
                            if !item.dimensions.isEmpty {
                                Text(item.dimensions)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondary)
                            }
                            
                            StatusBadge(status: item.status, label: item.statusLabel(language: language))
                        }
                        
                        Spacer()
                        
                        // Remove button
                        IconButton(systemImage: "xmark", action: onRemove, help: t("Remove this item", "移除此项目"))
                    }
                    
                    // OCR Results for images
                    if !item.ocrText.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack {
                                Text(t("Extracted Text", "提取文本"))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondary)
                                
                                Spacer()
                                
                                Button(action: toggleExpanded) {
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppColors.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if isExpanded {
                                // Full OCR text - editable
                                TextEditor(text: $item.ocrText)
                                    .appTextSurface(minHeight: 100, maxHeight: 200)
                            } else {
                                // Collapsed - first 5-8 lines
                                let lines = item.ocrText.split(separator: "\n", maxSplits: 7, omittingEmptySubsequences: false).prefix(5)
                                Text(lines.joined(separator: "\n"))
                                    .font(AppTypography.caption)
                                    .lineLimit(5)
                                    .foregroundStyle(AppColors.primary)
                                    .padding(AppSpacing.small)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .appSurface(.raised, padding: AppSpacing.small, radius: AppRadius.medium)
                            }
                        }
                    } else if item.status == .failed {
                        HStack(spacing: AppSpacing.small) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppColors.warning)
                            Text(t("Could not extract content.", "无法提取内容。"))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondary)
                        }
                        .padding(AppSpacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appSurface(.raised, padding: AppSpacing.small, radius: AppRadius.medium)
                    } else if item.type == .image {
                        // Image still processing
                        HStack(spacing: AppSpacing.small) {
                            Image(systemName: "hourglass")
                                .foregroundStyle(AppColors.secondary)
                            Text(t("Extracting text...", "正在提取文本..."))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondary)
                        }
                        .padding(AppSpacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appSurface(.raised, padding: AppSpacing.small, radius: AppRadius.medium)
                    }
                }
            }
        }
        .appSurface(.muted)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

struct CaptureWorkspaceItem: Identifiable {
    let id: UUID
    let name: String
    let type: CaptureItemType
    let sourceURL: URL?
    var thumbnail: NSImage?
    var dimensions: String = ""
    var ocrText: String = ""
    var status: StatusBadge.Status = .waiting
    var isRemoved: Bool = false
    
    var icon: String {
        switch type {
        case .image: return "photo.fill"
        case .pdf: return "doc.pdf.fill"
        case .officeDocument: return "doc.richtext.fill"
        case .url: return "link.fill"
        case .text: return "doc.text.fill"
        case .file: return "doc.fill"
        }
    }
    
    var statusLabel: String {
        statusLabel(language: AppLanguage.english.rawValue)
    }

    func statusLabel(language: String) -> String {
        switch status {
        case .waiting: return AppText.text("Waiting", "等待中", language: language)
        case .processing: return AppText.text("Processing", "处理中", language: language)
        case .completed:
            switch type {
            case .image: return AppText.text("OCR Complete", "OCR 完成", language: language)
            case .pdf: return AppText.text("Text Extracted", "已提取文本", language: language)
            case .officeDocument: return AppText.text("Text Extracted", "已提取文本", language: language)
            case .text: return AppText.text("Added", "已添加", language: language)
            case .url, .file: return AppText.text("Text Extracted", "已提取文本", language: language)
            }
        case .failed: return AppText.text("Failed", "失败", language: language)
        }
    }
}

enum CaptureItemType {
    case image
    case pdf
    case officeDocument
    case url
    case text
    case file
}
