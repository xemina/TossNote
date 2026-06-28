import SwiftUI
import AppKit

struct CaptureWorkspace: View {
    @Binding var captureItems: [CaptureWorkspaceItem]
    @State private var expandedItems: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            if captureItems.isEmpty {
                AppEmptyState(systemImage: "inbox", title: "No items captured")
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.medium) {
                        ForEach($captureItems) { $item in
                            if item.type == .text {
                                TextItemView(
                                    item: $item,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            } else if item.type == .url {
                                URLItemView(
                                    item: $item,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            } else if item.type == .image {
                                ImageItemView(
                                    item: $item,
                                    isExpanded: expandedItems.contains(item.id),
                                    toggleExpanded: { toggleExpanded(item.id) },
                                    onRemove: { removeItem(item.id) }
                                )
                            } else {
                                DocumentItemView(
                                    item: $item,
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
}

// MARK: - Document Item View
struct DocumentItemView: View {
    @Binding var item: CaptureWorkspaceItem
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

                StatusBadge(status: item.status, label: item.statusLabel)
                IconButton(systemImage: "xmark", action: onRemove, help: "Remove this document")
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
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.active)
                    }
                    .buttonStyle(.plain)
                }
            } else if item.status == .failed {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.warning)
                    Text("Could not extract content.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            } else if item.status == .processing || item.status == .waiting {
                HStack(spacing: AppSpacing.small) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Extracting document text...")
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
            return "PDF document"
        case .officeDocument:
            return "Office document"
        case .file:
            return "File"
        case .image:
            return "Image"
        case .url:
            return "Link"
        case .text:
            return "Text"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .pdf:
            return AppColors.error
        case .officeDocument:
            return AppColors.active
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
}

// MARK: - URL Item View
struct URLItemView: View {
    @Binding var item: CaptureWorkspaceItem
    var isExpanded: Bool
    var toggleExpanded: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.active)
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

                StatusBadge(status: item.status, label: item.statusLabel)
                IconButton(systemImage: "xmark", action: onRemove, help: "Remove this link")
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
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.active)
                    }
                    .buttonStyle(.plain)
                }
            } else if item.status == .processing || item.status == .waiting {
                HStack(spacing: AppSpacing.small) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Fetching link content...")
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
}

// MARK: - Text Item View (Simple, no image)
struct TextItemView: View {
    @Binding var item: CaptureWorkspaceItem
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
                
                IconButton(systemImage: "xmark", action: onRemove, help: "Remove this item")
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
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(AppColors.active)
                }
                .buttonStyle(.plain)
            }
        }
        .appSurface(.muted)
    }
}

// MARK: - Image Item View
struct ImageItemView: View {
    @Binding var item: CaptureWorkspaceItem
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
                            
                            StatusBadge(status: item.status, label: item.statusLabel)
                        }
                        
                        Spacer()
                        
                        // Remove button
                        IconButton(systemImage: "xmark", action: onRemove, help: "Remove this item")
                    }
                    
                    // OCR Results for images
                    if !item.ocrText.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack {
                                Text("Extracted Text")
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
                            Text("Could not extract content.")
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
                            Text("Extracting text...")
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
        switch status {
        case .waiting: return "Waiting"
        case .processing: return "Processing"
        case .completed:
            switch type {
            case .image: return "OCR Complete"
            case .pdf: return "Text Extracted"
            case .officeDocument: return "Text Extracted"
            case .text: return "Added"
            case .url, .file: return "Text Extracted"
            }
        case .failed: return "Failed"
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
