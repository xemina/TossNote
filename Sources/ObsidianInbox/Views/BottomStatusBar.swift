import SwiftUI

struct BottomStatusBar: View {
    @ObservedObject var viewModel: ContentViewModel
    var wordCount: Int
    var ocrCount: Int
    
    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            if let errorMessage = viewModel.errorMessage {
                // Show error message (red/orange)
                if errorMessage.contains("❌") {
                    // Configuration error
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    // Other error
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: viewModel.aiConfigurationStatus.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? .green : .red)
                Text(viewModel.aiConfigurationStatus.message)
                    .font(AppTypography.caption)
                    .foregroundStyle(viewModel.aiConfigurationStatus.isReady ? .green : .red)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("Words: \(wordCount)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .frame(height: AppSpacing.toolbarHeight)
        .background(AppColors.surface)
    }
}
