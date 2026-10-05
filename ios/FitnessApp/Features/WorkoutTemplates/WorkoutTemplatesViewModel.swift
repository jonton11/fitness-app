import Foundation

@MainActor
final class WorkoutTemplatesViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var activeSession: WorkoutSession?
    @Published private(set) var isLoading = false
    @Published private(set) var startingTemplateID: UUID?
    @Published var errorMessage: String?

    private let templateAPIClient: WorkoutTemplateAPIClient
    private let exerciseAPIClient: ExerciseAPIClient
    private let sessionAPIClient: WorkoutSessionAPIClient
    private let activeWorkoutStore: ActiveWorkoutStore

    init(
        templateAPIClient: WorkoutTemplateAPIClient = .live,
        exerciseAPIClient: ExerciseAPIClient = .live,
        sessionAPIClient: WorkoutSessionAPIClient = .live,
        activeWorkoutStore: ActiveWorkoutStore = .live
    ) {
        self.templateAPIClient = templateAPIClient
        self.exerciseAPIClient = exerciseAPIClient
        self.sessionAPIClient = sessionAPIClient
        self.activeWorkoutStore = activeWorkoutStore
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        refreshActiveSession()

        do {
            templates = try await templateAPIClient.listWorkoutTemplates()
            exercises = try await exerciseAPIClient.listExercises()
        } catch {
            errorMessage = "Could not load workout templates."
        }

        isLoading = false
    }

    func startWorkout(template: WorkoutTemplate) async -> WorkoutSession? {
        errorMessage = nil

        do {
            if let activeWorkoutState = try activeWorkoutStore.load() {
                activeSession = activeWorkoutState.session
                errorMessage = "Finish or cancel the active workout before starting another."
                return nil
            }
        } catch {
            errorMessage = "Could not load active workout."
            return nil
        }

        startingTemplateID = template.id
        defer {
            startingTemplateID = nil
        }

        do {
            let session = try await sessionAPIClient.startWorkoutSession(templateID: template.id)
            try activeWorkoutStore.save(ActiveWorkoutState(session: session))
            activeSession = session
            return session
        } catch {
            errorMessage = "Could not start workout."
            return nil
        }
    }

    func refreshActiveSession() {
        do {
            activeSession = try activeWorkoutStore.load()?.session
        } catch {
            errorMessage = "Could not load active workout."
        }
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
