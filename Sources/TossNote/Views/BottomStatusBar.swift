import SwiftUI

struct BottomStatusBar: View {
    @ObservedObject var viewModel: ContentViewModel
    var wordCount: Int
    var ocrCount: Int
    let language: String
    let themeMode: AppThemeMode
    let onToggleTheme: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            if let errorMessage = viewModel.errorMessage {
                let displayMessage = localizedErrorMessage(errorMessage)
                // Show error message (red/orange)
                if errorMessage.contains("❌") {
                    // Configuration error
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppColors.error)
                    Text(displayMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.error)
                        .lineLimit(1)
                } else {
                    // Other error
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.warning)
                    Text(displayMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warning)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: viewModel.aiConfigurationStatus.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? AppColors.success : AppColors.error)
                Text(localizedStatusMessage(viewModel.aiConfigurationStatus.message))
                    .font(AppTypography.caption)
                    .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? AppColors.success : AppColors.error)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(t("Words", "字数") + ": \(wordCount)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)

            ThemeStatusButton(
                themeMode: themeMode,
                label: t("Theme", "主题"),
                action: onToggleTheme
            )
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .frame(height: AppSpacing.toolbarHeight)
        .background(AppColors.surface)
    }

    private func localizedStatusMessage(_ message: String) -> String {
        guard language == AppLanguage.simplifiedChinese.rawValue else { return message }

        if message.hasPrefix("AI Ready:") {
            return message.replacingOccurrences(of: "AI Ready:", with: "AI 就绪：")
        }

        if message.hasPrefix("AI not checked:") {
            return message.replacingOccurrences(of: "AI not checked:", with: "AI 未检查：")
                .replacingOccurrences(of: "API key not loaded", with: "API Key 未加载")
        }

        if message.contains("API key missing") {
            return message.replacingOccurrences(of: "AI unavailable:", with: "AI 不可用：")
                .replacingOccurrences(of: "API key missing", with: "缺少 API Key")
        }

        if message.contains("model missing") {
            return message.replacingOccurrences(of: "AI unavailable:", with: "AI 不可用：")
                .replacingOccurrences(of: "model missing", with: "缺少模型")
        }

        if message.contains("endpoint missing") {
            return message.replacingOccurrences(of: "AI unavailable:", with: "AI 不可用：")
                .replacingOccurrences(of: "endpoint missing", with: "缺少 endpoint")
        }

        return message.replacingOccurrences(of: "AI unavailable", with: "AI 不可用")
    }

    private func localizedErrorMessage(_ message: String) -> String {
        guard language == AppLanguage.simplifiedChinese.rawValue else { return message }

        return message
            .replacingOccurrences(of: "No content to organize. Please paste or add some text first.", with: "没有可整理的内容。请先粘贴或添加文本。")
            .replacingOccurrences(of: "No markdown to save. Organize content first.", with: "没有可保存的 Markdown。请先整理内容。")
            .replacingOccurrences(of: "AI Processing Error", with: "AI 处理错误")
            .replacingOccurrences(of: "Configuration Issue", with: "配置问题")
            .replacingOccurrences(of: "API key is not configured", with: "尚未配置 API Key")
            .replacingOccurrences(of: "Please go to Settings and add your API key.", with: "请打开设置并添加 API Key。")
            .replacingOccurrences(of: "Model is not configured", with: "尚未配置模型")
            .replacingOccurrences(of: "Please choose or enter a model.", with: "请选择或输入模型。")
            .replacingOccurrences(of: "API endpoint is not configured", with: "尚未配置 API endpoint")
            .replacingOccurrences(of: "Please enter the full API endpoint.", with: "请输入完整的 API endpoint。")
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

private struct ThemeStatusButton: View {
    let themeMode: AppThemeMode
    let label: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(fillColor)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var icon: String {
        themeMode == .dark ? "sun.max.fill" : "moon.fill"
    }

    private var accentColor: Color {
        themeMode == .dark ? AppColors.sun : AppColors.moon
    }

    private var fillColor: Color {
        if themeMode == .dark {
            return isHovering ? AppColors.sun.opacity(0.18) : AppColors.surfaceRaised
        }

        return isHovering ? AppColors.moon.opacity(0.12) : AppColors.surfaceRaised
    }
}
