import Foundation

@MainActor
final class WorkoutTemplatesViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var activeSession: WorkoutSession?
    @Published private(set) var activeWorkoutTemplate: WorkoutTemplate?
    @Published private(set) var isLoading = false
    @Published private(set) var startingTemplateID: UUID?
    @Published var errorMessage: String?

    private let templateAPIClient: WorkoutTemplateAPIClient
    private let exerciseAPIClient: ExerciseAPIClient
    private let activeWorkoutStore: ActiveWorkoutStore
    private let configurationStore: WorkoutConfigurationStore
    private let now: () -> Date
    private let makeID: () -> UUID

    init(
        templateAPIClient: WorkoutTemplateAPIClient = .live,
        exerciseAPIClient: ExerciseAPIClient = .live,
        activeWorkoutStore: ActiveWorkoutStore = .live,
        configurationStore: WorkoutConfigurationStore = .live,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.templateAPIClient = templateAPIClient
        self.exerciseAPIClient = exerciseAPIClient
        self.activeWorkoutStore = activeWorkoutStore
        self.configurationStore = configurationStore
        self.now = now
        self.makeID = makeID
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        refreshActiveSession()
        var loadedCachedConfiguration = false

        do {
            if let cachedConfiguration = try configurationStore.load() {
                templates = cachedConfiguration.templates
                exercises = cachedConfiguration.exercises
                loadedCachedConfiguration = true
            }
        } catch {
            errorMessage = "Could not load saved workout templates."
        }

        do {
            async let fetchedTemplates = templateAPIClient.listWorkoutTemplates()
            async let fetchedExercises = exerciseAPIClient.listExercises()
            let (templates, exercises) = try await (fetchedTemplates, fetchedExercises)
            let configuration = WorkoutConfigurationSnapshot(templates: templates, exercises: exercises)
            self.templates = configuration.templates
            self.exercises = configuration.exercises
            errorMessage = nil
            do {
                try configurationStore.save(configuration)
            } catch {
                errorMessage = "Could not save workout templates for offline use."
            }
        } catch {
            if !loadedCachedConfiguration {
                errorMessage = "Could not load workout templates."
            }
        }

        isLoading = false
    }

    func startWorkout(template: WorkoutTemplate) async -> WorkoutSession? {
        errorMessage = nil

        do {
            if let activeWorkoutState = try activeWorkoutStore.load() {
                activeSession = activeWorkoutState.session
                activeWorkoutTemplate = activeWorkoutState.workoutTemplate
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
            let draft = try WorkoutSessionDraft(template: template, startedAt: now(), makeID: makeID)
            try activeWorkoutStore.save(
                ActiveWorkoutState(
                    session: draft.session,
                    workoutTemplate: template,
                    pendingSessionCreation: PendingWorkoutSessionCreation(payload: draft.payload)
                )
            )
            activeSession = draft.session
            activeWorkoutTemplate = template
            return draft.session
        } catch {
            errorMessage = "Could not start workout."
            return nil
        }
    }

    func refreshActiveSession() {
        do {
            let state = try activeWorkoutStore.load()
            activeSession = state?.session
            activeWorkoutTemplate = state?.workoutTemplate
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
            try configurationStore.save(
                WorkoutConfigurationSnapshot(templates: templates, exercises: exercises)
            )
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
