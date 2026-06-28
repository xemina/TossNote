import SwiftUI

struct TopToolbar: View {
    @ObservedObject var viewModel: ContentViewModel
    let language: String
    var onRead: () -> Void
    var onOrganize: () -> Void
    var onQuickSave: () -> Void
    var onSave: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.small) {
                ToolbarIconButton(
                    icon: "doc.on.clipboard",
                    label: t("Paste", "粘贴"),
                    action: onRead,
                    isEnabled: true,
                    accentColor: AppColors.active
                )
                
                ToolbarIconButton(
                    icon: "wand.and.stars",
                    label: t("Organize", "整理"),
                    action: onOrganize,
                    isEnabled: !viewModel.isProcessing,
                    accentColor: .purple
                )

                ToolbarIconButton(
                    icon: "bolt.fill",
                    label: t("Quick Save", "一键保存"),
                    action: onQuickSave,
                    isEnabled: !viewModel.isProcessing,
                    accentColor: AppColors.active,
                    isProminent: true
                )
                
                Spacer()
                
                if viewModel.isProcessing {
                    HStack(spacing: AppSpacing.small) {
                        ProgressView()
                            .scaleEffect(0.75)
                        Text(t("Working...", "处理中..."))
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.secondary)
                    }
                    .appSurface(.muted, padding: AppSpacing.small, radius: AppRadius.medium, borderColor: .clear)
                    .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                
                ToolbarIconButton(
                    icon: "square.and.arrow.down",
                    label: t("Save", "保存"),
                    action: onSave,
                    isEnabled: true,
                    accentColor: AppColors.success
                )
                
                ToolbarIconButton(
                    icon: "gearshape",
                    label: t("Settings", "设置"),
                    action: onSettings,
                    isEnabled: true,
                    accentColor: .gray
                )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.small)
            .frame(height: AppSpacing.toolbarHeight)
            
            Divider()
                .opacity(0.15)
        }
        .background(AppColors.surface)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        AppText.text(english, chinese, language: language)
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var isEnabled: Bool = true
    var accentColor: Color = .blue
    var isProminent = false
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(label)
                    .font(AppTypography.captionMedium)
                    .lineLimit(1)
            }
            .frame(width: 68, height: 46)
            .foregroundStyle(isProminent && isEnabled ? .white : (isEnabled ? accentColor : AppColors.secondary))
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(prominentFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(isHovering && isEnabled ? accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering && isEnabled
            }
        }
    }

    private var prominentFill: Color {
        if isProminent && isEnabled {
            return isHovering ? accentColor.opacity(0.9) : accentColor
        }

        return isHovering && isEnabled ? accentColor.opacity(0.12) : Color.clear
    }
}
