import SwiftUI

struct TopToolbar: View {
    @ObservedObject var viewModel: ContentViewModel
    var onRead: () -> Void
    var onOrganize: () -> Void
    var onSave: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.small) {
                ToolbarIconButton(
                    icon: "doc.on.clipboard",
                    label: "Paste",
                    action: onRead,
                    isEnabled: true,
                    accentColor: .blue
                )
                
                ToolbarIconButton(
                    icon: "wand.and.stars",
                    label: "Organize",
                    action: onOrganize,
                    isEnabled: !viewModel.isProcessing,
                    accentColor: .purple
                )
                
                Spacer()
                
                if viewModel.isProcessing {
                    HStack(spacing: AppSpacing.small) {
                        ProgressView()
                            .scaleEffect(0.75)
                        Text("Organizing...")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.secondary)
                    }
                    .appSurface(.muted, padding: AppSpacing.small, radius: AppRadius.medium, borderColor: .clear)
                    .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                
                ToolbarIconButton(
                    icon: "square.and.arrow.down",
                    label: "Save",
                    action: onSave,
                    isEnabled: true,
                    accentColor: AppColors.success
                )
                
                ToolbarIconButton(
                    icon: "gearshape",
                    label: "Settings",
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
}

struct ToolbarIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var isEnabled: Bool = true
    var accentColor: Color = .blue
    
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
            .foregroundStyle(isEnabled ? accentColor : AppColors.secondary)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(isHovering && isEnabled ? accentColor.opacity(0.12) : Color.clear)
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
}
