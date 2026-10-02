import Foundation

@MainActor
final class WorkoutTemplatesViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let templateAPIClient: WorkoutTemplateAPIClient
    private let exerciseAPIClient: ExerciseAPIClient

    init(
        templateAPIClient: WorkoutTemplateAPIClient = .live,
        exerciseAPIClient: ExerciseAPIClient = .live
    ) {
        self.templateAPIClient = templateAPIClient
        self.exerciseAPIClient = exerciseAPIClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            templates = try await templateAPIClient.listWorkoutTemplates()
            exercises = try await exerciseAPIClient.listExercises()
        } catch {
            errorMessage = "Could not load workout templates."
        }

        isLoading = false
    }

    func save(form: WorkoutTemplateFormState, template: WorkoutTemplate?) async -> Bool {
        errorMessage = nil

        do {
            let payload = form.payload(lockVersion: template?.lockVersion)
            let savedTemplate = try await saveTemplate(payload, existingTemplate: template)
            upsert(savedTemplate)
            return true
        } catch {
            errorMessage = "Could not save workout template."
            return false
        }
    }

    private func saveTemplate(
        _ payload: WorkoutTemplatePayload,
        existingTemplate: WorkoutTemplate?
    ) async throws -> WorkoutTemplate {
        if let existingTemplate {
            return try await templateAPIClient.updateWorkoutTemplate(id: existingTemplate.id, payload: payload)
        }

        return try await templateAPIClient.createWorkoutTemplate(payload)
    }

    private func upsert(_ template: WorkoutTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }

        templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
