import SwiftUI

class AppTheme: ObservableObject, @unchecked Sendable {
    @Published var isDarkMode: Bool = false {
        didSet {
            save()
        }
    }
    
    nonisolated static let shared = AppTheme()
    
    init() {
        load()
    }
    
    nonisolated private func load() {
        isDarkMode = UserDefaults.standard.bool(forKey: "AppTheme.isDarkMode")
    }
    
    nonisolated private func save() {
        UserDefaults.standard.set(isDarkMode, forKey: "AppTheme.isDarkMode")
    }
}

struct AppThemeKey: EnvironmentKey {
    nonisolated static let defaultValue = AppTheme()
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
