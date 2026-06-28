import SwiftUI

enum AppSurfaceLevel {
    case base
    case raised
    case muted
    case selected
    
    var fill: Color {
        switch self {
        case .base:
            return AppColors.surface
        case .raised:
            return AppColors.surfaceRaised
        case .muted:
            return AppColors.surfaceMuted
        case .selected:
            return AppColors.selectedBackground
        }
    }
}

struct AppSurfaceModifier: ViewModifier {
    let level: AppSurfaceLevel
    let padding: CGFloat
    let radius: CGFloat
    let borderColor: Color
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(level.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func appSurface(
        _ level: AppSurfaceLevel = .base,
        padding: CGFloat = AppSpacing.medium,
        radius: CGFloat = AppRadius.large,
        borderColor: Color = AppColors.subtleBorder
    ) -> some View {
        modifier(AppSurfaceModifier(level: level, padding: padding, radius: radius, borderColor: borderColor))
    }
    
    func appTextSurface(minHeight: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View {
        self
            .font(AppTypography.body)
            .scrollContentBackground(.hidden)
            .padding(AppSpacing.small)
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.subtleBorder, lineWidth: 1)
            )
    }
}

struct AppSectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.active)
                .frame(width: 18)
            
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.primary)
            
            Spacer()
        }
    }
}

struct AppEmptyState: View {
    let systemImage: String
    let title: String
    
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppColors.tertiary)
            
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
