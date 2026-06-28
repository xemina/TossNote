import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case simplifiedChinese = "简体中文"

    var id: String { rawValue }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppText {
    static func text(_ english: String, _ chinese: String, language: String) -> String {
        language == AppLanguage.simplifiedChinese.rawValue ? chinese : english
    }
}
