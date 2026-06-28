import SwiftUI

struct AppPanelStyle: ViewModifier {
    let backgroundColor: Color
    let padding: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(AppRadius.medium)
    }
}

struct AppGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            configuration.label
                .font(AppTypography.sectionTitle)
            
            configuration.content
        }
        .padding(AppSpacing.medium)
        .background(AppColors.subtleBackground)
        .cornerRadius(AppRadius.medium)
    }
}

extension View {
    func appPanel(
        backgroundColor: Color = AppColors.textBackground,
        padding: CGFloat = AppSpacing.panelPadding
    ) -> some View {
        modifier(AppPanelStyle(backgroundColor: backgroundColor, padding: padding))
    }
}

// MARK: - Dialog Styles

struct AppDialogStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.large)
            .background(AppColors.controlBackground)
            .cornerRadius(AppRadius.large)
            .shadow(radius: 2)
    }
}

extension View {
    func appDialog() -> some View {
        modifier(AppDialogStyle())
    }
}

// MARK: - Section Styles

struct AppSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            content
        }
        .padding(AppSpacing.medium)
        .background(AppColors.subtleBackground)
        .cornerRadius(AppRadius.medium)
    }
}

extension View {
    func appSection() -> some View {
        modifier(AppSectionStyle())
    }
}
