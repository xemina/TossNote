import Foundation

enum StorageTarget: String, CaseIterable, Identifiable {
    case obsidian = "Obsidian"
    case localFolder = "Local Folder"
    case joplin = "Joplin"

    var id: String { rawValue }
}
