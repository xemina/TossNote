import SwiftUI

struct TagView: View {
    let text: String
    let onRemove: (() -> Void)?
    var backgroundColor: Color = AppColors.subtleBackground
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.primary)
            
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xs)
        .background(backgroundColor)
        .cornerRadius(AppRadius.small)
    }
}
