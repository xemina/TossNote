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
    @State private var hasLoadedJoplinToken = false
    
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
                        inputWordCount: $inputWordCount,
                        language: appLanguage
                    )
                        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                    
                    PreviewPanel(markdown: $markdown, language: appLanguage)
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
                ocrCount: 0,
                language: appLanguage,
                themeMode: selectedThemeMode,
                onToggleTheme: toggleThemeMode
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
            loadJoplinTokenIfNeeded()
            checkAIConfigurationOnStartup()
        }
        .onChange(of: joplinToken) { newValue in
            guard hasLoadedJoplinToken else { return }
            LocalSecretStore.save(newValue, account: joplinTokenAccount)
        }
        .onChange(of: appThemeMode) { _ in
            if let settingsWindow {
                applyTheme(to: settingsWindow)
            }
        }
        .alert(t("Configuration Issue", "配置问题"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(t("Open Settings", "打开设置")) {
                openSettingsWindow()
            }
            Button(t("OK", "好的"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(localizedErrorMessage(viewModel.errorMessage ?? ""))
        }
    }
    
    private func checkAIConfigurationOnStartup() {
        viewModel.refreshAIConfigurationStatus()
        let validation = viewModel.validateAISetup(loadStoredAPIKey: false)
        if !validation.isValid {
            viewModel.errorMessage = nil
        } else {
            viewModel.errorMessage = nil
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: appLanguage)
    }

    private func localizedErrorMessage(_ message: String) -> String {
        guard appLanguage == AppLanguage.simplifiedChinese.rawValue else { return message }

        return message
            .replacingOccurrences(of: "No content to organize. Please paste or add some text first.", with: "没有可整理的内容。请先粘贴或添加文本。")
            .replacingOccurrences(of: "No markdown to save. Organize content first.", with: "没有可保存的 Markdown。请先整理内容。")
            .replacingOccurrences(of: "AI Processing Error", with: "AI 处理错误")
            .replacingOccurrences(of: "API key is not configured", with: "尚未配置 API Key")
            .replacingOccurrences(of: "Please go to Settings and add your API key.", with: "请打开设置并添加 API Key。")
            .replacingOccurrences(of: "Model is not configured", with: "尚未配置模型")
            .replacingOccurrences(of: "Please choose or enter a model.", with: "请选择或输入模型。")
            .replacingOccurrences(of: "API endpoint is not configured", with: "尚未配置 API endpoint")
            .replacingOccurrences(of: "Please enter the full API endpoint.", with: "请输入完整的 API endpoint。")
    }

    private var joplinTokenAccount: String {
        "joplin-web-clipper-token"
    }

    private func loadJoplinTokenIfNeeded() {
        guard !hasLoadedJoplinToken else { return }

        let localToken = LocalSecretStore.read(account: joplinTokenAccount)
        if !localToken.isEmpty {
            joplinToken = localToken
            hasLoadedJoplinToken = true
            return
        }

        guard let legacyToken = UserDefaults.standard.string(forKey: "joplinToken"),
              !legacyToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            hasLoadedJoplinToken = true
            return
        }

        LocalSecretStore.save(legacyToken, account: joplinTokenAccount)
        UserDefaults.standard.removeObject(forKey: "joplinToken")
        joplinToken = legacyToken
        hasLoadedJoplinToken = true
    }

    private var activeWordCount: Int {
        let editedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return editedMarkdown.isEmpty ? 0 : editedMarkdown.wordCount
    }
    
    private func openSettingsWindow() {
        if let settingsWindow {
            applyTheme(to: settingsWindow)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        viewModel.loadAPIKeyForSettingsIfNeeded()
        loadJoplinTokenIfNeeded()
        
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
        window.title = t("Settings", "设置")
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        applyTheme(to: window)
        let delegate = SettingsWindowDelegate(onClose: {
            settingsWindow = nil
            settingsWindowDelegate = nil
        })
        settingsWindowDelegate = delegate
        window.delegate = delegate
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    private func applyTheme(to window: NSWindow) {
        window.appearance = NSAppearance(
            named: selectedThemeMode == .dark ? .darkAqua : .aqua
        )
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
            viewModel.errorMessage = t("No content to organize. Please paste or add some text first.", "没有可整理的内容。请先粘贴或添加文本。")
            return nil
        }
        
        guard !hasPendingCaptureProcessing else {
            viewModel.errorMessage = t("Some input items are still being processed. Please wait for extraction to finish.", "部分输入项目仍在处理中，请等待内容提取完成。")
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
            viewModel.errorMessage = t("No markdown to save. Organize content first.", "没有可保存的 Markdown。请先整理内容。")
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
                let targetName = selectedStorageTarget == .obsidian ? "Obsidian" : t("Local Folder", "本地文件夹")
                showTransientSuccess(t("Saved to", "已保存到") + " \(targetName): \(savedURL.lastPathComponent)")
            case .joplin:
                let savedNote = try await joplinWriter.save(
                    markdown: markdownToSave,
                    port: joplinPort,
                    token: joplinToken,
                    notebookName: joplinNotebook,
                    attachments: capturedAttachments
                )
                viewModel.errorMessage = nil
                showTransientSuccess(t("Saved to Joplin", "已保存到 Joplin") + ": \(savedNote.title)")
            }
        } catch let error as JoplinError {
            viewModel.errorMessage = t("Failed to save to Joplin", "保存到 Joplin 失败") + ": \(error.localizedDescription)"
        } catch {
            viewModel.errorMessage = t("Failed to save", "保存失败") + ": \(error.localizedDescription)"
        }
    }

    private var selectedStorageTarget: StorageTarget {
        StorageTarget(rawValue: storageTarget) ?? .obsidian
    }

    private var selectedThemeMode: AppThemeMode {
        AppThemeMode(rawValue: appThemeMode) ?? .light
    }

    private func toggleThemeMode() {
        appThemeMode = selectedThemeMode == .dark ? AppThemeMode.light.rawValue : AppThemeMode.dark.rawValue
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
        loadJoplinTokenIfNeeded()

        let token = joplinToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = joplinPort.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            viewModel.errorMessage = t("Joplin API token is not configured. Open Settings > Storage and paste the Web Clipper token.", "尚未配置 Joplin API token。请打开 设置 > 存储，粘贴 Web Clipper token。")
            return false
        }

        guard let portNumber = Int(port), portNumber > 0 else {
            viewModel.errorMessage = t("Joplin port is invalid. The default Web Clipper port is 41184.", "Joplin 端口无效。Web Clipper 默认端口是 41184。")
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
        let targetLabel = selectedStorageTarget == .obsidian ? t("Obsidian vault", "Obsidian 仓库") : t("local storage", "本地存储")

        guard !path.isEmpty else {
            viewModel.errorMessage = t("\(targetLabel.capitalized) folder is not configured. Open Settings > Storage and choose a local folder.", "\(targetLabel)文件夹尚未配置。请打开 设置 > 存储，选择本地文件夹。")
            return false
        }

        if selectedStorageTarget == .obsidian {
            guard !folder.isEmpty else {
                viewModel.errorMessage = t("Inbox folder is not configured. Open Settings > Storage and enter a folder name.", "Inbox 文件夹尚未配置。请打开 设置 > 存储，输入文件夹名称。")
                return false
            }
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            viewModel.errorMessage = t("\(targetLabel.capitalized) folder does not exist. Open Settings > Storage and choose a valid local folder.", "\(targetLabel)文件夹不存在。请打开 设置 > 存储，选择有效的本地文件夹。")
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
                            AIAndProvidersSettingsView(viewModel: viewModel, language: appLanguage)
                        case .vault:
                            StorageSettingsView(
                                storageTarget: $storageTarget,
                                vaultPath: $vaultPath,
                                folderName: $folderName,
                                joplinPort: $joplinPort,
                                joplinToken: $joplinToken,
                                joplinNotebook: $joplinNotebook,
                                language: appLanguage
                            )
                        case .prompt:
                            PromptSettingsView(viewModel: viewModel, language: appLanguage)
                        case .language:
                            LanguageSettingsView(
                                appLanguage: $appLanguage
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
        .preferredColorScheme(selectedThemeMode.colorScheme)
    }

    private var selectedThemeMode: AppThemeMode {
        AppThemeMode(rawValue: appThemeMode) ?? .light
    }
}

// MARK: - Settings Enums & Components
enum SettingsTab: String, CaseIterable {
    case ai = "AI"
    case vault = "Storage"
    case prompt = "Prompt"
    case language = "Language"
    
    func title(language: String) -> String {
        switch self {
        case .ai:
            return AppText.text("AI", "AI", language: language)
        case .vault:
            return AppText.text("Storage", "存储", language: language)
        case .prompt:
            return AppText.text("Prompt", "提示词", language: language)
        case .language:
            return AppText.text("Language", "语言", language: language)
        }
    }
    
    var icon: String {
        switch self {
        case .ai: return "sparkles"
        case .vault: return "folder.fill"
        case .prompt: return "quote.bubble.fill"
        case .language: return "globe"
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
        .foregroundStyle(isSelected ? AppColors.activeStrong : AppColors.primary)
    }
}

// MARK: - Settings Subviews
struct AIAndProvidersSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    let language: String
    @State private var showAPIKey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: viewModel.aiConfigurationStatus.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? AppColors.success : AppColors.error)
                    
                    Text(viewModel.aiConfigurationStatus.message)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? AppColors.success : AppColors.error)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(viewModel.aiConfigurationStatus.isReady ? .selected : .muted)
            
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: t("AI Provider", "AI 服务商"), systemImage: "brain.head.profile")
                
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
                AppSectionHeader(title: t("Model & Endpoint", "模型和 Endpoint"), systemImage: "cpu")
                
                Divider()

                if viewModel.selectedProvider == "Custom" {
                    SettingsField(label: t("API Format", "API 格式")) {
                        Picker("", selection: $viewModel.customAPIFormat) {
                            ForEach(CustomAPIFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(AppColors.active)
                        .controlSize(.regular)
                        .frame(maxWidth: 360, alignment: .leading)
                    }
                }
                
                SettingsField(label: t("Model", "模型")) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        if !viewModel.availableModels.isEmpty {
                            Picker("", selection: modelPickerSelection) {
                                ForEach(viewModel.availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                                Text(t("Custom model ID", "自定义模型 ID")).tag(customModelTag)
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.active)
                            .controlSize(.regular)
                            .frame(maxWidth: 260, alignment: .leading)
                        }
                        
                        if viewModel.usesFreeformModel || isUsingCustomModel {
                            TextField(modelPlaceholder(for: viewModel.selectedProvider), text: $viewModel.selectedModel)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                SettingsField(label: viewModel.usesEditableEndpoint ? t("API Endpoint", "API Endpoint") : "Endpoint") {
                    if viewModel.usesEditableEndpoint {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack(spacing: AppSpacing.small) {
                                TextField(endpointPlaceholder(for: viewModel.selectedProvider), text: $viewModel.customAPIURL)
                                    .textFieldStyle(.roundedBorder)

                                if viewModel.selectedProvider != "Custom" {
                                    SecondaryButton(
                                        label: t("Use Default", "使用默认值"),
                                        systemImage: "arrow.counterclockwise",
                                        action: { viewModel.restoreDefaultEndpoint() },
                                        tint: AppColors.settings
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
                AppSectionHeader(title: t("API Credentials", "API 凭证"), systemImage: "key.fill")
                
                HStack(spacing: AppSpacing.small) {
                    if showAPIKey {
                        TextField(apiKeyPlaceholder(for: viewModel.selectedProvider), text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField(t("Enter your API key", "输入 API Key"), text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    IconButton(
                        systemImage: showAPIKey ? "eye.slash.fill" : "eye.fill",
                        action: { showAPIKey.toggle() },
                        help: showAPIKey ? t("Hide API key", "隐藏 API Key") : t("Show API key", "显示 API Key"),
                        tint: AppColors.settings
                    )
                }
                
                HStack(spacing: AppSpacing.medium) {
                    SecondaryButton(
                        label: viewModel.isTestingAIConnection ? t("Testing...", "测试中...") : t("Test Connection", "测试连接"),
                        systemImage: "bolt.horizontal.circle.fill",
                        action: { Task { await viewModel.testAIConnection() } },
                        isEnabled: !viewModel.isTestingAIConnection,
                        tint: AppColors.organize
                    )
                    
                    if let testMessage = viewModel.aiConnectionTestMessage {
                        Text(testMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(viewModel.aiConnectionTestSucceeded == true ? AppColors.success : AppColors.error)
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
            return t("Gateway", "网关")
        case "Custom":
            return t("Compatible", "兼容")
        default:
            return t("Official", "官方")
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

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
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
                        .foregroundStyle(isSelected ? AppColors.activeInk.opacity(0.78) : AppColors.secondary)
                }
                
                Text(name)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(isSelected ? AppColors.active : AppColors.surfaceRaised)
            .foregroundStyle(isSelected ? AppColors.activeInk : AppColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
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
    let language: String

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
            SettingsSection(title: t("Storage Target", "存储目标"), icon: "externaldrive.fill") {
                SettingsField(label: t("Target", "目标")) {
                    Picker("", selection: storageTargetBinding) {
                        ForEach(StorageTarget.allCases) { target in
                            Text(target.rawValue).tag(target.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppColors.active)
                    .controlSize(.regular)
                    .frame(maxWidth: 280)
                }
            }

            if selectedStorageTarget == .obsidian || selectedStorageTarget == .localFolder {
                SettingsSection(title: localStorageTitle, icon: "folder.fill") {
                    SettingsField(label: selectedStorageTarget == .obsidian ? t("Vault Path", "仓库路径") : t("Storage Folder", "存储文件夹")) {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack(spacing: AppSpacing.small) {
                                TextField(localStoragePlaceholder, text: $vaultPath)
                                    .textFieldStyle(.roundedBorder)

                                SecondaryButton(
                                    label: t("Choose Folder", "选择文件夹"),
                                    systemImage: "folder",
                                    action: chooseLocalFolder,
                                    tint: AppColors.save
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
                        SettingsField(label: t("Inbox Folder", "Inbox 文件夹")) {
                            TextField("Inbox", text: $folderName).textFieldStyle(.roundedBorder)
                        }
                    } else {
                        Text(t("Markdown files and attachments are saved directly into this folder.", "Markdown 文件和附件会直接保存到这个文件夹。"))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                SettingsSection(title: t("Joplin Configuration", "Joplin 配置"), icon: "tray.full.fill") {
                    SettingsField(label: t("Web Clipper Port", "Web Clipper 端口")) {
                        TextField("41184", text: $joplinPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                    }

                    SettingsField(label: t("API Token", "API Token")) {
                        SecureField(t("Paste Joplin Web Clipper token", "粘贴 Joplin Web Clipper token"), text: $joplinToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    SettingsField(label: t("Notebook", "笔记本")) {
                        TextField("Inbox", text: $joplinNotebook)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text(t("Enable Web Clipper in Joplin, then copy the authorization token from Joplin settings. The app saves notes through Joplin's local API.", "请在 Joplin 中启用 Web Clipper，然后从 Joplin 设置复制授权 token。本应用会通过 Joplin 本地 API 保存笔记。"))
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
                ? t("Choose your Obsidian vault folder before organizing or saving.", "整理或保存前请选择 Obsidian 仓库文件夹。")
                : t("Choose a local folder before organizing or saving.", "整理或保存前请选择本地文件夹。")
        }

        return isVaultPathValid ? t("Folder is available.", "文件夹可用。") : t("Folder not found. Choose an existing local folder.", "找不到文件夹。请选择已存在的本地文件夹。")
    }

    private var localStorageTitle: String {
        selectedStorageTarget == .obsidian ? t("Obsidian Configuration", "Obsidian 配置") : t("Local Folder Configuration", "本地文件夹配置")
    }

    private var localStoragePlaceholder: String {
        selectedStorageTarget == .obsidian ? "/path/to/obsidian/vault" : "/path/to/local/folder"
    }

    private func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.title = selectedStorageTarget == .obsidian ? t("Choose Obsidian Vault Folder", "选择 Obsidian 仓库文件夹") : t("Choose Local Storage Folder", "选择本地存储文件夹")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        if panel.runModal() == .OK, let url = panel.url {
            vaultPath = url.path
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

struct LanguageSettingsView: View {
    @Binding var appLanguage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            SettingsSection(title: AppText.text("Language", "语言", language: appLanguage), icon: "globe") {
                SettingsField(label: AppText.text("Interface Language", "界面语言", language: appLanguage)) {
                    Picker("", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.rawValue).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppColors.active)
                    .controlSize(.regular)
                    .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
    }
}

struct PromptSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            SettingsSection(title: t("Title Format", "标题格式"), icon: "textformat") {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Text(viewModel.customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? t("Using AI Default Title", "使用 AI 默认标题") : t("Custom Title Format Active", "自定义标题格式已启用"))
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(viewModel.customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.secondary : AppColors.activeStrong)

                        Spacer()

                        SecondaryButton(
                            label: t("Restore Default", "恢复默认"),
                            systemImage: "arrow.counterclockwise",
                            action: { viewModel.restoreDefaultTitleFormat() },
                            isEnabled: !viewModel.customTitleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            tint: AppColors.settings
                        )
                    }

                    TextField("Example: {{date}} - {{source}} - {{topic}}", text: $viewModel.customTitleFormat)
                        .textFieldStyle(.roundedBorder)

                    Text(t("Placeholders", "占位符") + ": {{date}}, {{topic}}, {{source}}, {{type}}, {{project}}, {{person}}, {{language}}")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: t("AI Prompts", "AI 提示词"), icon: "quote.bubble.fill") {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Text(viewModel.isUsingCustomPrompt ? t("Custom Prompt Active", "自定义提示词已启用") : t("Using System Default Prompt", "使用系统默认提示词"))
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(viewModel.isUsingCustomPrompt ? AppColors.activeStrong : AppColors.secondary)
                        
                        Spacer()
                        
                        SecondaryButton(
                            label: t("Restore Default", "恢复默认"),
                            systemImage: "arrow.counterclockwise",
                            action: { viewModel.restoreDefaultPrompt() },
                            isEnabled: viewModel.isUsingCustomPrompt,
                            tint: AppColors.settings
                        )
                    }
                    
                    Text(t("System Prompt", "系统提示词"))
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

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
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
