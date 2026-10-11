import Foundation

@MainActor
final class WorkoutSuggestionViewModel: ObservableObject {
    @Published private(set) var suggestion: WorkoutSuggestion?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let fetchSuggestion: () async throws -> WorkoutSuggestion?

    init(apiClient: WorkoutTemplateAPIClient = .live) {
        fetchSuggestion = {
            try await apiClient.getWorkoutSuggestion()
        }
    }

    init(fetchSuggestion: @escaping () async throws -> WorkoutSuggestion?) {
        self.fetchSuggestion = fetchSuggestion
    }

    func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            suggestion = try await fetchSuggestion()
        } catch {
            suggestion = nil
            errorMessage = "Could not load a workout suggestion."
        }
    }
}
