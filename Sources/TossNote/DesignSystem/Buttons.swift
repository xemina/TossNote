import SwiftUI

struct PrimaryButton: View {
    let label: String
    let systemImage: String?
    let action: () -> Void
    var isEnabled: Bool = true
    var isFullWidth: Bool = false
    var tint: Color = AppColors.active
    var foreground: Color = AppColors.activeInk
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(label)
                    .font(AppTypography.bodyMedium)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isEnabled ? (isHovering ? tint.opacity(0.86) : tint) : AppColors.surfaceMuted)
            )
            .foregroundStyle(isEnabled ? foreground : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering && isEnabled
            }
        }
    }
}

struct SecondaryButton: View {
    let label: String
    let systemImage: String?
    let action: () -> Void
    var isEnabled: Bool = true
    var isFullWidth: Bool = false
    var tint: Color = AppColors.primary
    var fill: Color? = nil
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(label)
                    .font(AppTypography.bodyMedium)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(secondaryFill)
            )
            .foregroundStyle(isEnabled ? tint : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering && isEnabled
            }
        }
    }

    private var secondaryFill: Color {
        guard isEnabled else { return AppColors.surfaceRaised }
        if let fill {
            return isHovering ? fill.opacity(0.72) : fill
        }
        return isHovering ? tint.opacity(0.10) : AppColors.surfaceRaised
    }
}

struct IconButton: View {
    let systemImage: String
    let action: () -> Void
    var isEnabled: Bool = true
    var help: String? = nil
    var tint: Color = AppColors.secondary
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : AppColors.tertiary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(isHovering && isEnabled ? tint.opacity(0.10) : AppColors.surfaceRaised)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help ?? "")
        .opacity(isEnabled ? 1 : 0.65)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering && isEnabled
            }
        }
    }
}
