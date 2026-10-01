import Foundation

@MainActor
final class ExercisesViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: ExerciseAPIClient

    init(apiClient: ExerciseAPIClient = .live) {
        self.apiClient = apiClient
    }

    func loadExercises() async {
        isLoading = true
        errorMessage = nil

        do {
            exercises = try await apiClient.listExercises()
        } catch {
            errorMessage = "Could not load exercises."
        }

        isLoading = false
    }

    func save(form: ExerciseFormState, exercise: Exercise?) async -> Bool {
        errorMessage = nil

        do {
            let payload = form.payload(lockVersion: exercise?.lockVersion)
            let savedExercise = try await saveExercise(payload, existingExercise: exercise)
            upsert(savedExercise)
            return true
        } catch {
            errorMessage = "Could not save exercise."
            return false
        }
    }

    private func saveExercise(
        _ payload: ExercisePayload,
        existingExercise: Exercise?
    ) async throws -> Exercise {
        if let existingExercise {
            return try await apiClient.updateExercise(id: existingExercise.id, payload: payload)
        }

        return try await apiClient.createExercise(payload)
    }

    private func upsert(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        } else {
            exercises.append(exercise)
        }

        exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
