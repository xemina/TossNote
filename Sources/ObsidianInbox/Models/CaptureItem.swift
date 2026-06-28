import Foundation

struct CaptureItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: CaptureType
    let source: CaptureSource
    let content: String
    let metadata: [String: String]
    var status: ProcessingStatus
    let createdAt: Date
    
    init(
        name: String,
        type: CaptureType,
        source: CaptureSource,
        content: String,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.source = source
        self.content = content
        self.metadata = metadata
        self.status = .waiting
        self.createdAt = Date()
    }
}

enum CaptureType: String, Codable {
    case text
    case image
    case pdf
    case url
    case file
    case clipboard
}

enum CaptureSource: String, Codable {
    case dragDrop
    case clipboard
    case paste
}

enum ProcessingStatus: String, Codable {
    case waiting
    case capturing
    case extracting
    case organizing
    case building
    case saving
    case completed
    case failed
    
    var icon: String {
        switch self {
        case .waiting: return "circle"
        case .capturing, .extracting, .organizing, .building, .saving: return "hourglass"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .capturing: return "Capturing"
        case .extracting: return "Extracting"
        case .organizing: return "Organizing"
        case .building: return "Building"
        case .saving: return "Saving"
        case .completed: return "Complete"
        case .failed: return "Failed"
        }
    }
}
