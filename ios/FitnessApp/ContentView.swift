import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var connectionSettings: ConnectionSettingsViewModel
    @StateObject private var healthSync: HealthSyncViewModel

    init(
        connectionSettings: ConnectionSettingsViewModel = ConnectionSettingsViewModel(),
        healthSync: HealthSyncViewModel = HealthSyncViewModel()
    ) {
        connectionSettings.onCredentialsChange = {
            healthSync.resetForCredentialChange()
        }
        _connectionSettings = StateObject(wrappedValue: connectionSettings)
        _healthSync = StateObject(wrappedValue: healthSync)
    }

    var body: some View {
        if connectionSettings.hasCredentials {
            mainTabs
        } else {
            NavigationStack {
                ConnectionSettingsView(
                    viewModel: connectionSettings,
                    isRequired: true,
                    healthSyncViewModel: healthSync
                )
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            WorkoutTemplatesView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }

            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            ExercisesView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet.rectangle")
                }

            NavigationStack {
                ConnectionSettingsView(
                    viewModel: connectionSettings,
                    healthSyncViewModel: healthSync
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task {
            await healthSync.syncIfEnabled()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }
            Task {
                await healthSync.syncIfEnabled()
            }
        }
    }
}
