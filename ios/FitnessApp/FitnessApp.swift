import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearancePreference"

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

@main
struct FitnessApp: App {
    @AppStorage(AppearancePreference.storageKey)
    private var appearancePreference = AppearancePreference.system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearancePreference.colorScheme)
        }
    }
}
