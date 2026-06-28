import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var markdown = ""
    @State private var capturedContent = ""
    @State private var capturedAttachments: [CapturedAttachment] = []
    @State private var hasPendingCaptureProcessing = false
    @State private var inputWordCount = 0
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    
    private let writer = ObsidianWriter()
    private let joplinWriter = JoplinWriter()
    
    @AppStorage("storageTarget") private var storageTarget = StorageTarget.obsidian.rawValue
    @AppStorage("vaultPath") private var vaultPath = ""
    @AppStorage("folderName") private var folderName = "Inbox"
    @AppStorage("joplinPort") private var joplinPort = "41184"
    @AppStorage("joplinNotebook") private var joplinNotebook = "Inbox"
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english.rawValue
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.light.rawValue
    @State private var joplinToken = ""
    
    @State private var settingsWindow: NSWindow?
    @State private var settingsWindowDelegate: SettingsWindowDelegate?
    
    var body: some View {
        VStack(spacing: 0) {
            TopToolbar(
                viewModel: viewModel,
                language: appLanguage,
                onRead: { pasteFromClipboard() },
                onOrganize: { Task { await organizeAllItems() } },
                onQuickSave: { Task { await organizeAndSaveAllItems() } },
                onSave: { Task { await saveMarkdown() } },
                onSettings: { openSettingsWindow() }
            )
            
            Divider()
            
            ZStack {
                HSplitView {
                    CapturePanel(
                        capturedContent: $capturedContent,
                        hasPendingProcessing: $hasPendingCaptureProcessing,
                        capturedAttachments: $capturedAttachments,
                        inputWordCount: $inputWordCount
                    )
                        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                    
                    PreviewPanel(markdown: $markdown)
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            
            Divider()
            
            BottomStatusBar(
                viewModel: viewModel,
                wordCount: activeWordCount,
                ocrCount: 0
            )
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(AppColors.background)
        .preferredColorScheme(selectedThemeMode.colorScheme)
        .overlay(alignment: .bottom) {
            if showSuccessMessage {
                SaveResultToast(message: successMessage)
                    .padding(.bottom, AppSpacing.toolbarHeight + AppSpacing.medium)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            loadSecureSettings()
            checkAIConfigurationOnStartup()
        }
        .onChange(of: joplinToken) { newValue in
            KeychainStore.save(newValue, account: joplinTokenAccount)
        }
        .alert("⚠️ Configuration Issue", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Open Settings") {
                openSettingsWindow()
            }
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private func checkAIConfigurationOnStartup() {
        viewModel.refreshAIConfigurationStatus()
        let validation = viewModel.validateAISetup()
        if !validation.isValid {
            viewModel.errorMessage = validation.message
        } else {
            viewModel.errorMessage = nil
        }
    }

    private var joplinTokenAccount: String {
        "joplin-web-clipper-token"
    }

    private func loadSecureSettings() {
        let keychainToken = KeychainStore.read(account: joplinTokenAccount)
        if !keychainToken.isEmpty {
            joplinToken = keychainToken
            return
        }

        guard let legacyToken = UserDefaults.standard.string(forKey: "joplinToken"),
              !legacyToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        KeychainStore.save(legacyToken, account: joplinTokenAccount)
        UserDefaults.standard.removeObject(forKey: "joplinToken")
        joplinToken = legacyToken
    }

    private var activeWordCount: Int {
        let editedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return editedMarkdown.isEmpty ? 0 : editedMarkdown.wordCount
    }
    
    private func openSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let settingsView = SettingsWindowView(
            viewModel: viewModel,
            storageTarget: $storageTarget,
            vaultPath: $vaultPath,
            folderName: $folderName,
            joplinPort: $joplinPort,
            joplinToken: $joplinToken,
            joplinNotebook: $joplinNotebook,
            appLanguage: $appLanguage,
            appThemeMode: $appThemeMode
        )
        
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        let delegate = SettingsWindowDelegate(onClose: {
            settingsWindow = nil
            settingsWindowDelegate = nil
        })
        settingsWindowDelegate = delegate
        window.delegate = delegate
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // First, try to get image from clipboard
        if let image = NSImage(pasteboard: pasteboard) {
            // Save image to temp file
            if let tempURL = saveImageToTemp(image) {
                // Post notification with image URL
                NotificationCenter.default.post(
                    name: NSNotification.Name("PasteImageItem"),
                    object: tempURL
                )
            }
        }
        // If no image, try text
        else if let text = pasteboard.string(forType: .string) {
            NotificationCenter.default.post(
                name: NSNotification.Name("PasteTextItem"),
                object: text
            )
        }
    }
    
    private func saveImageToTemp(_ image: NSImage) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = UUID().uuidString + ".png"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    @MainActor
    private func organizeAllItems() async {
        guard let result = await organizeCurrentInput() else { return }
        markdown = result
        viewModel.errorMessage = nil
    }

    @MainActor
    private func organizeAndSaveAllItems() async {
        guard let result = await organizeCurrentInput() else { return }
        markdown = result
        await saveMarkdown(result)
    }

    @MainActor
    private func organizeCurrentInput() async -> String? {
        guard validateStorageConfiguration() else { return nil }

        // First validate AI setup
        let validation = viewModel.validateAISetup()
        
        if !validation.isValid {
            // Show error in status bar
            viewModel.errorMessage = validation.message
            viewModel.refreshAIConfigurationStatus()
            return nil
        }
        
        let input = capturedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !input.isEmpty else {
            viewModel.errorMessage = "No content to organize. Please paste or add some text first."
            return nil
        }
        
        guard !hasPendingCaptureProcessing else {
            viewModel.errorMessage = "Some input items are still being processed. Please wait for extraction to finish."
            return nil
        }
        
        if let result = await viewModel.organize(input: input) {
            viewModel.errorMessage = nil
            return result
        }
        // Error message is already set by viewModel.organize()
        return nil
    }
    
    @MainActor
    private func saveMarkdown() async {
        await saveMarkdown(markdown)
    }

    @MainActor
    private func saveMarkdown(_ markdownToSave: String) async {
        guard validateStorageConfiguration() else { return }

        guard !markdownToSave.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.errorMessage = "No markdown to save. Organize content first."
            return
        }

        do {
            switch selectedStorageTarget {
            case .obsidian, .localFolder:
                let savedURL = try writer.save(
                    markdown: markdownToSave,
                    vaultPath: vaultPath,
                    folderName: folderName,
                    attachments: capturedAttachments,
                    usesOutputSubfolder: selectedStorageTarget == .obsidian,
                    storesAttachmentsInSubfolder: selectedStorageTarget == .obsidian
                )
                viewModel.errorMessage = nil
                let targetName = selectedStorageTarget == .obsidian ? "Obsidian" : "Local Folder"
                showTransientSuccess("Saved to \(targetName): \(savedURL.lastPathComponent)")
            case .joplin:
                let savedNote = try await joplinWriter.save(
                    markdown: markdownToSave,
                    port: joplinPort,
                    token: joplinToken,
                    notebookName: joplinNotebook,
                    attachments: capturedAttachments
                )
                viewModel.errorMessage = nil
                showTransientSuccess("Saved to Joplin: \(savedNote.title)")
            }
        } catch let error as JoplinError {
            viewModel.errorMessage = "Failed to save to Joplin: \(error.localizedDescription)"
        } catch {
            viewModel.errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private var selectedStorageTarget: StorageTarget {
        StorageTarget(rawValue: storageTarget) ?? .obsidian
    }

    private var selectedThemeMode: AppThemeMode {
        AppThemeMode(rawValue: appThemeMode) ?? .light
    }

    private func validateStorageConfiguration() -> Bool {
        switch selectedStorageTarget {
        case .obsidian, .localFolder:
            return validateLocalFolderConfiguration()
        case .joplin:
            return validateJoplinConfiguration()
        }
    }

    private func validateJoplinConfiguration() -> Bool {
        let token = joplinToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = joplinPort.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            viewModel.errorMessage = "Joplin API token is not configured. Open Settings > Storage and paste the Web Clipper token."
            return false
        }

        guard let portNumber = Int(port), portNumber > 0 else {
            viewModel.errorMessage = "Joplin port is invalid. The default Web Clipper port is 41184."
            return false
        }

        return true
    }

    private func showTransientSuccess(_ message: String) {
        successMessage = message

        withAnimation(.easeOut(duration: 0.18)) {
            showSuccessMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard successMessage == message else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                showSuccessMessage = false
            }
        }
    }

    private func validateLocalFolderConfiguration() -> Bool {
        let path = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLabel = selectedStorageTarget == .obsidian ? "Obsidian vault" : "local storage"

        guard !path.isEmpty else {
            viewModel.errorMessage = "\(targetLabel.capitalized) folder is not configured. Open Settings > Storage and choose a local folder."
            return false
        }

        if selectedStorageTarget == .obsidian {
            guard !folder.isEmpty else {
                viewModel.errorMessage = "Inbox folder is not configured. Open Settings > Storage and enter a folder name."
                return false
            }
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            viewModel.errorMessage = "\(targetLabel.capitalized) folder does not exist. Open Settings > Storage and choose a valid local folder."
            return false
        }

        return true
    }
}

final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

struct SaveResultToast: View {
    let message: String

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)

            Text(message)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(AppColors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.subtleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .frame(maxWidth: 420)
    }
}

// MARK: - Settings Window
struct SettingsWindowView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var storageTarget: String
    @Binding var vaultPath: String
    @Binding var folderName: String
    @Binding var joplinPort: String
    @Binding var joplinToken: String
    @Binding var joplinNotebook: String
    @Binding var appLanguage: String
    @Binding var appThemeMode: String
    
    @State private var selectedTab: SettingsTab = .ai
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsSidebarButton(
                        tab: tab,
                        language: appLanguage,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
                Spacer()
                Text("Version \(AppVersion.current)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.medium)
            }
            .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
            .background(AppColors.controlBackground)
            
            // Content
            VStack(spacing: 0) {
                HStack {
                    Text(selectedTab.title(language: appLanguage))
                        .font(AppTypography.sectionTitle)
                    Spacer()
                }
                .padding(AppSpacing.medium)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        switch selectedTab {
                        case .ai:
                            AIAndProvidersSettingsView(viewModel: viewModel)
                        case .vault:
                            StorageSettingsView(
                                storageTarget: $storageTarget,
                                vaultPath: $vaultPath,
                                folderName: $folderName,
                                joplinPort: $joplinPort,
                                joplinToken: $joplinToken,
                                joplinNotebook: $joplinNotebook
                            )
                        case .prompt:
                            PromptSettingsView(viewModel: viewModel)
                        case .appearance:
                            AppearanceSettingsView(
                                appLanguage: $appLanguage,
                                appThemeMode: $appThemeMode
                            )
                        }
                    }
                    .padding(AppSpacing.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        }
        .frame(minWidth: 580, minHeight: 400)
        .background(AppColors.background)
    }
}

// MARK: - Settings Enums & Components
enum SettingsTab: String, CaseIterable {
    case ai = "AI"
    case vault = "Storage"
    case prompt = "Prompt"
    case appearance = "Appearance"
    
    func title(language: String) -> String {
        switch self {
        case .ai:
            return AppText.text("AI", "AI", language: language)
        case .vault:
            return AppText.text("Storage", "存储", language: language)
        case .prompt:
            return AppText.text("Prompt", "提示词", language: language)
        case .appearance:
            return AppText.text("Appearance", "外观", language: language)
        }
    }
    
    var icon: String {
        switch self {
        case .ai: return "sparkles"
        case .vault: return "folder.fill"
        case .prompt: return "quote.bubble.fill"
        case .appearance: return "paintpalette.fill"
        }
    }
}

struct SettingsSidebarButton: View {
    let tab: SettingsTab
    let language: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24)
                Text(tab.title(language: language))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, 12)
            .background(isSelected ? AppColors.dropBackground : .clear)
            .cornerRadius(AppRadius.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AppColors.active : AppColors.primary)
    }
}

// MARK: - Settings Subviews
struct AIAndProvidersSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var showAPIKey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: viewModel.aiConfigurationStatus.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? .green : .red)
                    
                    Text(viewModel.aiConfigurationStatus.message)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? .green : .red)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(viewModel.aiConfigurationStatus.isReady ? .selected : .muted)
            
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "AI Provider", systemImage: "brain.head.profile")
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: AppSpacing.small) {
                    ForEach(viewModel.availableProviders, id: \.self) { provider in
                        ProviderChoiceButton(
                            name: provider,
                            kind: providerKind(for: provider),
                            icon: providerIcon(for: provider),
                            isSelected: viewModel.selectedProvider == provider,
                            action: { viewModel.selectedProvider = provider }
                        )
                    }
                }
            }
            .appSurface(.muted)
            
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Model & Endpoint", systemImage: "cpu")
                
                Divider()

                if viewModel.selectedProvider == "Custom" {
                    SettingsField(label: "API Format") {
                        Picker("", selection: $viewModel.customAPIFormat) {
                            ForEach(CustomAPIFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360, alignment: .leading)
                    }
                }
                
                SettingsField(label: "Model") {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        if !viewModel.availableModels.isEmpty {
                            Picker("", selection: modelPickerSelection) {
                                ForEach(viewModel.availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                                Text("Custom model ID").tag(customModelTag)
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 260, alignment: .leading)
                        }
                        
                        if viewModel.usesFreeformModel || isUsingCustomModel {
                            TextField(modelPlaceholder(for: viewModel.selectedProvider), text: $viewModel.selectedModel)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                SettingsField(label: viewModel.usesEditableEndpoint ? "API Endpoint" : "Endpoint") {
                    if viewModel.usesEditableEndpoint {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack(spacing: AppSpacing.small) {
                                TextField(endpointPlaceholder(for: viewModel.selectedProvider), text: $viewModel.customAPIURL)
                                    .textFieldStyle(.roundedBorder)

                                if viewModel.selectedProvider != "Custom" {
                                    SecondaryButton(
                                        label: "Use Default",
                                        systemImage: "arrow.counterclockwise",
                                        action: { viewModel.restoreDefaultEndpoint() }
                                    )
                                }
                            }

                            Text(endpointHelpText(for: viewModel.selectedProvider))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(endpointDisplayText)
                            .font(AppTypography.monospace)
                            .foregroundStyle(AppColors.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .appSurface(.muted)
            
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "API Credentials", systemImage: "key.fill")
                
                HStack(spacing: AppSpacing.small) {
                    if showAPIKey {
                        TextField(apiKeyPlaceholder(for: viewModel.selectedProvider), text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter your API key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(AppColors.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: AppSpacing.medium) {
                    Button(action: { Task { await viewModel.testAIConnection() } }) {
                        HStack(spacing: AppSpacing.small) {
                            if viewModel.isTestingAIConnection {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.horizontal.circle.fill")
                            }
                            Text(viewModel.isTestingAIConnection ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(viewModel.isTestingAIConnection)
                    
                    if let testMessage = viewModel.aiConnectionTestMessage {
                        Text(testMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(viewModel.aiConnectionTestSucceeded == true ? .green : .red)
                            .lineLimit(2)
                    }
                }
            }
            .appSurface(.muted)
        }
    }
    
    private let customModelTag = "__custom_model_id__"
    
    private var modelPickerSelection: Binding<String> {
        Binding(
            get: {
                viewModel.availableModels.contains(viewModel.selectedModel)
                    ? viewModel.selectedModel
                    : customModelTag
            },
            set: { value in
                viewModel.selectedModel = value == customModelTag ? "" : value
            }
        )
    }
    
    private var isUsingCustomModel: Bool {
        !viewModel.selectedModel.isEmpty && !viewModel.availableModels.contains(viewModel.selectedModel)
            || viewModel.selectedModel.isEmpty
    }
    
    private func providerIcon(for name: String) -> String {
        switch name.lowercased() {
        case "openai": return "sparkles"
        case "deepseek": return "magnifyingglass.circle"
        case "google gemini": return "diamond.fill"
        case "openrouter": return "arrow.triangle.branch"
        case "anyrouter": return "point.3.connected.trianglepath.dotted"
        case "custom": return "server.rack"
        default: return "gearshape.2"
        }
    }
    
    private func providerKind(for name: String) -> String {
        switch name {
        case "OpenRouter", "AnyRouter":
            return "Gateway"
        case "Custom":
            return "Compatible"
        default:
            return "Official"
        }
    }
    
    private func modelPlaceholder(for provider: String) -> String {
        switch provider {
        case "OpenRouter":
            return "provider/model"
        case "AnyRouter":
            return "Model ID"
        case "Custom":
            return "Model ID"
        default:
            return "Exact model ID"
        }
    }
    
    private func apiKeyPlaceholder(for provider: String) -> String {
        switch provider {
        case "Google Gemini":
            return "Gemini API key"
        case "OpenRouter":
            return "OpenRouter API key"
        case "AnyRouter":
            return "AnyRouter API key"
        default:
            return "sk-..."
        }
    }
    
    private func endpointPlaceholder(for provider: String) -> String {
        switch provider {
        case "OpenRouter":
            return "https://openrouter.ai/api/v1/chat/completions"
        case "AnyRouter":
            return "https://anyrouter.top/v1/chat/completions"
        case "Custom" where viewModel.customAPIFormat == .anthropicMessages:
            return "https://api.example.com/v1"
        default:
            return "https://api.example.com/v1/chat/completions"
        }
    }

    private func endpointHelpText(for provider: String) -> String {
        switch provider {
        case "OpenRouter", "AnyRouter":
            return "Editable because gateway providers may use custom domains. You can enter the base /v1 URL or the full /chat/completions endpoint."
        case "Custom" where viewModel.customAPIFormat == .anthropicMessages:
            return "Enter the provider base URL, such as https://api.example.com/v1, or the full /v1/messages endpoint."
        case "Custom":
            return "Enter an OpenAI-compatible base URL, such as https://api.example.com/v1, or the full /v1/chat/completions endpoint."
        default:
            return "Official provider endpoints are managed by the app."
        }
    }
    
    private var endpointDisplayText: String {
        if viewModel.selectedProvider == "Google Gemini" {
            return "https://generativelanguage.googleapis.com/v1beta/models/\(viewModel.selectedModel):generateContent"
        }
        
        return viewModel.currentURL?.absoluteString ?? "N/A"
    }
}

struct ProviderChoiceButton: View {
    let name: String
    let kind: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                    Spacer()
                    Text(kind)
                        .font(AppTypography.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : AppColors.secondary)
                }
                
                Text(name)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(isSelected ? AppColors.active : AppColors.surfaceRaised)
            .foregroundStyle(isSelected ? .white : AppColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(isSelected ? AppColors.active : AppColors.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StorageSettingsView: View {
    @Binding var storageTarget: String
    @Binding var vaultPath: String
    @Binding var folderName: String
    @Binding var joplinPort: String
    @Binding var joplinToken: String
    @Binding var joplinNotebook: String

    private var resolvedVaultPath: String {
        vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isVaultPathValid: Bool {
        guard !resolvedVaultPath.isEmpty else { return false }
        let expandedPath = (resolvedVaultPath as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            SettingsSection(title: "Storage Target", icon: "externaldrive.fill") {
                SettingsField(label: "Target") {
                    Picker("", selection: storageTargetBinding) {
                        ForEach(StorageTarget.allCases) { target in
                            Text(target.rawValue).tag(target.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }
            }

            if selectedStorageTarget == .obsidian || selectedStorageTarget == .localFolder {
                SettingsSection(title: localStorageTitle, icon: "folder.fill") {
                    SettingsField(label: selectedStorageTarget == .obsidian ? "Vault Path" : "Storage Folder") {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack(spacing: AppSpacing.small) {
                                TextField(localStoragePlaceholder, text: $vaultPath)
                                    .textFieldStyle(.roundedBorder)

                                SecondaryButton(
                                    label: "Choose Folder",
                                    systemImage: "folder",
                                    action: chooseLocalFolder
                                )
                            }

                            HStack(spacing: AppSpacing.small) {
                                Image(systemName: isVaultPathValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(isVaultPathValid ? AppColors.success : AppColors.secondary)

                                Text(vaultStatusText)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(isVaultPathValid ? AppColors.success : AppColors.secondary)
                            }
                        }
                    }
                    if selectedStorageTarget == .obsidian {
                        SettingsField(label: "Inbox Folder") {
                            TextField("Inbox", text: $folderName).textFieldStyle(.roundedBorder)
                        }
                    } else {
                        Text("Markdown files and attachments are saved directly into this folder.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                SettingsSection(title: "Joplin Configuration", icon: "tray.full.fill") {
                    SettingsField(label: "Web Clipper Port") {
                        TextField("41184", text: $joplinPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                    }

                    SettingsField(label: "API Token") {
                        SecureField("Paste Joplin Web Clipper token", text: $joplinToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    SettingsField(label: "Notebook") {
                        TextField("Inbox", text: $joplinNotebook)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text("Enable Web Clipper in Joplin, then copy the authorization token from Joplin settings. The app saves notes through Joplin's local API.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var selectedStorageTarget: StorageTarget {
        StorageTarget(rawValue: storageTarget) ?? .obsidian
    }

    private var storageTargetBinding: Binding<String> {
        Binding(
            get: { selectedStorageTarget.rawValue },
            set: { storageTarget = StorageTarget(rawValue: $0)?.rawValue ?? StorageTarget.obsidian.rawValue }
        )
    }

    private var vaultStatusText: String {
        if resolvedVaultPath.isEmpty {
            return selectedStorageTarget == .obsidian
                ? "Choose your Obsidian vault folder before organizing or saving."
                : "Choose a local folder before organizing or saving."
        }

        return isVaultPathValid ? "Folder is available." : "Folder not found. Choose an existing local folder."
    }

    private var localStorageTitle: String {
        selectedStorageTarget == .obsidian ? "Obsidian Configuration" : "Local Folder Configuration"
    }

    private var localStoragePlaceholder: String {
        selectedStorageTarget == .obsidian ? "/path/to/obsidian/vault" : "/path/to/local/folder"
    }

    private func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.title = selectedStorageTarget == .obsidian ? "Choose Obsidian Vault Folder" : "Choose Local Storage Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        if panel.runModal() == .OK, let url = panel.url {
            vaultPath = url.path
        }
    }
}

struct AppearanceSettingsView: View {
    @Binding var appLanguage: String
    @Binding var appThemeMode: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            SettingsSection(title: "Language", icon: "globe") {
                SettingsField(label: "Interface Language") {
                    Picker("", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.rawValue).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
            }

            SettingsSection(title: "Theme", icon: "circle.lefthalf.filled") {
                SettingsField(label: "Color Mode") {
                    Picker("", selection: $appThemeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                HStack(spacing: AppSpacing.small) {
                    Circle()
                        .fill(AppColors.active)
                        .frame(width: 18, height: 18)

                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .fill(AppColors.surfaceRaised)
                        .frame(width: 42, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(AppColors.subtleBorder, lineWidth: 1)
                        )
                }
            }
        }
    }
}

struct PromptSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            SettingsSection(title: "Title Format", icon: "textformat") {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Text(viewModel.customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Using AI Default Title" : "Custom Title Format Active")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(viewModel.customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.secondary : AppColors.active)

                        Spacer()

                        SecondaryButton(
                            label: "Restore Default",
                            systemImage: "arrow.counterclockwise",
                            action: { viewModel.restoreDefaultTitleFormat() },
                            isEnabled: !viewModel.customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }

                    TextField("Example: {{date}} - {{source}} - {{topic}}", text: $viewModel.customTitleFormat)
                        .textFieldStyle(.roundedBorder)

                    Text("Placeholders: {{date}}, {{topic}}, {{source}}, {{type}}, {{project}}, {{person}}, {{language}}")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: "AI Prompts", icon: "quote.bubble.fill") {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Text(viewModel.isUsingCustomPrompt ? "Custom Prompt Active" : "Using System Default Prompt")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(viewModel.isUsingCustomPrompt ? AppColors.active : AppColors.secondary)
                        
                        Spacer()
                        
                        SecondaryButton(
                            label: "Restore Default",
                            systemImage: "arrow.counterclockwise",
                            action: { viewModel.restoreDefaultPrompt() },
                            isEnabled: viewModel.isUsingCustomPrompt
                        )
                    }
                    
                    Text("System Prompt")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                    
                    TextEditor(text: promptBinding)
                        .appTextSurface(minHeight: 180, maxHeight: 260)
                }
            }
        }
    }
    
    private var promptBinding: Binding<String> {
        Binding(
            get: {
                viewModel.isUsingCustomPrompt ? viewModel.customSystemPrompt : viewModel.defaultSystemPrompt
            },
            set: { newValue in
                viewModel.customSystemPrompt = newValue
            }
        )
    }
}

// MARK: - Reusable Settings Components
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: title, systemImage: icon)
            
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appSurface(.muted)
    }
}

struct SettingsField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
            content
        }
    }
}
