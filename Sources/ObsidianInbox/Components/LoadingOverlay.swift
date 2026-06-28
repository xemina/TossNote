import SwiftUI

struct LoadingOverlay: View {
    let isVisible: Bool
    var message: String?
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.medium) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppColors.active)
                    
                    if let message = message {
                        Text(message)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(AppSpacing.large)
                .background(AppColors.controlBackground)
                .cornerRadius(AppRadius.large)
            }
        }
    }
}

