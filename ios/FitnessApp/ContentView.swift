import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Personal fitness")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .textCase(.uppercase)

                Text("Fitness")
                    .font(.largeTitle.weight(.bold))

                Text("iPhone client foundation is running.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .navigationTitle("Home")
        }
    }
}
