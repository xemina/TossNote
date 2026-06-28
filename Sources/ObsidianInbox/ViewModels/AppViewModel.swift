import SwiftUI
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var captureViewModel = CaptureViewModel()
    @Published var previewViewModel = PreviewViewModel()
    @Published var selectedTab = 0
    @Published var showSettings = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let aiClient = OpenAIClient()
    private let writer = ObsidianWriter()
    
    @AppStorage("selectedProvider") var selectedProvider = "OpenAI"
    @AppStorage("selectedModel") var selectedModel = "gpt-4"
    @AppStorage("vaultPath") var vaultPath = ""
    @AppStorage("folderName") var folderName = "Inbox"
    
    func organize() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        guard !previewViewModel.markdown.isEmpty else {
            errorMessage = "No content to organize"
            return
        }
        
        do {
            let organized = try await aiClient.organize(
                input: previewViewModel.markdown,
                apiKey: "",
                model: selectedModel,
                apiURL: URL(string: "https://api.openai.com/v1")!,
                providerName: selectedProvider
            )
            
            previewViewModel.markdown = organized
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func save() async {
        guard !previewViewModel.markdown.isEmpty else {
            errorMessage = "No markdown to save"
            return
        }

        let path = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = folderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty else {
            errorMessage = "Obsidian vault folder is not configured"
            return
        }

        guard !folder.isEmpty else {
            errorMessage = "Inbox folder is not configured"
            return
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = "Obsidian vault folder does not exist"
            return
        }
        
        do {
            let _ = try writer.save(
                markdown: previewViewModel.markdown,
                vaultPath: vaultPath,
                folderName: folderName
            )
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    func readClipboard() {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string) {
            previewViewModel.markdown = text
        }
    }
}
