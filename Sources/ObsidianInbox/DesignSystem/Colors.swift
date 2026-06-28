import SwiftUI

enum AppColors {
    static let primary = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let tertiary = Color(nsColor: .tertiaryLabelColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let controlBackground = Color(nsColor: .controlBackgroundColor)
    static let textBackground = Color(nsColor: .textBackgroundColor)
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
    static let active = Color(red: 0.22, green: 0.48, blue: 0.36)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceRaised = Color(nsColor: .textBackgroundColor)
    static let surfaceMuted = Color.gray.opacity(0.06)
    static let selectedBackground = active.opacity(0.12)
    static let subtleBackground = Color.gray.opacity(0.05)
    static let dropBackground = active.opacity(0.07)
    static let subtleBorder = Color.secondary.opacity(0.18)
    static let strongBorder = Color.secondary.opacity(0.28)
}
