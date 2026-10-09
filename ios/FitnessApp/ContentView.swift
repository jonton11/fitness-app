import SwiftUI

struct ContentView: View {
    @StateObject private var connectionSettings: ConnectionSettingsViewModel

    init(connectionSettings: ConnectionSettingsViewModel = ConnectionSettingsViewModel()) {
        _connectionSettings = StateObject(wrappedValue: connectionSettings)
    }

    var body: some View {
        if connectionSettings.hasCredentials {
            mainTabs
        } else {
            NavigationStack {
                ConnectionSettingsView(viewModel: connectionSettings, isRequired: true)
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            ActivitiesView()
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
                ConnectionSettingsView(viewModel: connectionSettings)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
