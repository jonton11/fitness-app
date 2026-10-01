import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Personal fitness")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .textCase(.uppercase)

                    Text("Fitness")
                        .font(.largeTitle.weight(.bold))

                    Text("Workout templates and exercise management are available in the tabs.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
                .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            WorkoutTemplatesView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }

            ExercisesView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet.rectangle")
                }
        }
    }
}
