import SwiftUI
import Foundation

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var items: [CaptureItem] = []
    @Published var selectedItem: CaptureItem?
    @Published var isProcessing = false
    @Published var error: String?
    
    private let captureService: CaptureService
    private let extractorService: ContentExtractor
    
    init(
        captureService: CaptureService = CaptureService(),
        extractorService: ContentExtractor = ContentExtractor()
    ) {
        self.captureService = captureService
        self.extractorService = extractorService
    }
    
    func addItem(_ item: CaptureItem) {
        items.append(item)
        selectedItem = item
    }
    
    func removeItem(_ item: CaptureItem) {
        items.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = items.last
        }
    }
    
    func processItem(_ item: CaptureItem) async {
        var mutableItem = item
        mutableItem.status = .capturing
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = mutableItem
        }
        
        let _ = await extractorService.extract(from: URL(fileURLWithPath: ""))
        mutableItem.status = .completed
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = mutableItem
        }
    }
    
    func clearAll() {
        items.removeAll()
        selectedItem = nil
    }
}

// MARK: - Capture Service

class CaptureService {
    func capture(from url: URL) async -> CaptureItem? {
        let name = url.lastPathComponent
        let type: CaptureType = determineCaptureType(url)
        
        return CaptureItem(
            name: name,
            type: type,
            source: .dragDrop,
            content: ""
        )
    }
    
    private func determineCaptureType(_ url: URL) -> CaptureType {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "pdf": return .pdf
        case "png", "jpg", "jpeg", "heic", "gif", "tiff": return .image
        default: return .file
        }
    }
}
