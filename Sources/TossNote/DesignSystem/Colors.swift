import SwiftUI

enum AppColors {
    static let primary = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let tertiary = Color(nsColor: .tertiaryLabelColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let controlBackground = Color(nsColor: .controlBackgroundColor)
    static let textBackground = Color(nsColor: .textBackgroundColor)
    static let active = Color(red: 0.75, green: 0.85, blue: 0.76) // #BFD8C1
    static let activeStrong = Color(red: 0.25, green: 0.43, blue: 0.31)
    static let activeInk = Color(red: 0.12, green: 0.20, blue: 0.15)
    static let success = activeStrong
    static let error = Color(red: 0.72, green: 0.18, blue: 0.16)
    static let warning = Color(red: 0.74, green: 0.44, blue: 0.14)
    static let paste = Color(red: 0.24, green: 0.48, blue: 0.68)
    static let pasteFill = Color(red: 0.87, green: 0.94, blue: 0.98)
    static let organize = Color(red: 0.48, green: 0.36, blue: 0.66)
    static let organizeFill = Color(red: 0.94, green: 0.90, blue: 0.98)
    static let quickSave = active
    static let save = Color(red: 0.20, green: 0.47, blue: 0.34)
    static let saveFill = Color(red: 0.88, green: 0.95, blue: 0.90)
    static let settings = Color(red: 0.36, green: 0.40, blue: 0.45)
    static let settingsFill = Color(red: 0.92, green: 0.93, blue: 0.94)
    static let sun = Color(red: 0.82, green: 0.50, blue: 0.12)
    static let moon = Color(red: 0.36, green: 0.42, blue: 0.70)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceRaised = Color(nsColor: .textBackgroundColor)
    static let surfaceMuted = active.opacity(0.12)
    static let selectedBackground = active.opacity(0.36)
    static let subtleBackground = active.opacity(0.10)
    static let dropBackground = active.opacity(0.22)
    static let subtleBorder = activeStrong.opacity(0.20)
    static let strongBorder = activeStrong.opacity(0.34)
}
