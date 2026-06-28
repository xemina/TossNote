import SwiftUI

struct StatusBadge: View {
    enum Status: Equatable {
        case waiting
        case processing
        case completed
        case failed
        
        var icon: String {
            switch self {
            case .waiting: return "circle"
            case .processing: return "hourglass"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .waiting: return AppColors.secondary
            case .processing: return AppColors.activeStrong
            case .completed: return AppColors.success
            case .failed: return AppColors.error
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .waiting: return AppColors.subtleBackground
            case .processing: return AppColors.dropBackground
            case .completed: return AppColors.success.opacity(0.08)
            case .failed: return AppColors.error.opacity(0.05)
            }
        }
    }
    
    let status: Status
    var label: String?
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(status.color)
            
            if let label = label {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xs)
        .background(status.backgroundColor)
        .cornerRadius(AppRadius.small)
    }
}
