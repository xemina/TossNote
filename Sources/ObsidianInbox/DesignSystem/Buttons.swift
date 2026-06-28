import SwiftUI

struct PrimaryButton: View {
    let label: String
    let systemImage: String?
    let action: () -> Void
    var isEnabled: Bool = true
    var isFullWidth: Bool = false
    
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
                    .fill(isEnabled ? AppColors.active : AppColors.surfaceMuted)
            )
            .foregroundStyle(isEnabled ? .white : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
    }
}

struct SecondaryButton: View {
    let label: String
    let systemImage: String?
    let action: () -> Void
    var isEnabled: Bool = true
    var isFullWidth: Bool = false
    
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
                    .fill(AppColors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.subtleBorder, lineWidth: 1)
            )
            .foregroundStyle(isEnabled ? AppColors.primary : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
    }
}

struct IconButton: View {
    let systemImage: String
    let action: () -> Void
    var isEnabled: Bool = true
    var help: String? = nil
    var tint: Color = AppColors.secondary
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : AppColors.tertiary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.subtleBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help ?? "")
        .opacity(isEnabled ? 1 : 0.65)
    }
}
