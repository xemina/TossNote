import Foundation

struct CapturedAttachment: Identifiable, Equatable {
    let id: UUID
    let name: String
    let sourceURL: URL
    let kind: Kind

    enum Kind: String {
        case image
        case document
    }
}
