import Foundation

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    @Published private(set) var session: WorkoutSession
    @Published private(set) var workoutTemplate: WorkoutTemplate?
    @Published private(set) var selectedExerciseID: UUID?
    @Published var repDraft = ""
    @Published var loadDraft = ""
    @Published var errorMessage: String?
    @Published private(set) var restEndsAt: Date?
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var syncIssueCount = 0

    private let store: ActiveWorkoutStore
    private let getWorkoutSession: (UUID) async throws -> WorkoutSession
    private let updateWorkoutSession: (UUID, WorkoutSessionStatusPayload) async throws -> WorkoutSession
    private let updateWorkoutSessionExercise: (UUID, WorkoutSessionExerciseUpdatePayload) async throws -> WorkoutSessionExercise
    private let updateWorkoutSessionSet: (UUID, WorkoutSessionSetUpdatePayload) async throws -> WorkoutSessionSet
    private let createExerciseOption: (WorkoutTemplateExerciseOptionCreatePayload) async throws -> WorkoutTemplateExerciseOption
    private let now: () -> Date
    private var pendingSetUpdates: [PendingWorkoutSessionSetUpdate] = [] {
        didSet {
            refreshPendingSyncCount()
        }
    }
    private var pendingSessionUpdate: PendingWorkoutSessionUpdate? {
        didSet {
            refreshPendingSyncCount()
        }
    }
    private var syncIssues: [WorkoutSessionSetSyncIssue] = [] {
        didSet {
            syncIssueCount = syncIssues.count
        }
    }

    init(
        session: WorkoutSession,
        workoutTemplate: WorkoutTemplate? = nil,
        store: ActiveWorkoutStore = .live,
        now: @escaping () -> Date = Date.init,
        getWorkoutSession: @escaping (UUID) async throws -> WorkoutSession = { id in
            try await WorkoutSessionAPIClient.live.getWorkoutSession(id: id)
        },
        updateWorkoutSession: @escaping (UUID, WorkoutSessionStatusPayload) async throws -> WorkoutSession = { id, payload in
            try await WorkoutSessionAPIClient.live.updateWorkoutSession(id: id, payload: payload)
        },
        updateWorkoutSessionExercise: @escaping (UUID, WorkoutSessionExerciseUpdatePayload) async throws -> WorkoutSessionExercise = { id, payload in
            try await WorkoutSessionAPIClient.live.updateWorkoutSessionExercise(id: id, payload: payload)
        },
        updateWorkoutSessionSet: @escaping (UUID, WorkoutSessionSetUpdatePayload) async throws -> WorkoutSessionSet = { id, payload in
            try await WorkoutSessionAPIClient.live.updateWorkoutSessionSet(id: id, payload: payload)
        },
        createExerciseOption: @escaping (WorkoutTemplateExerciseOptionCreatePayload) async throws -> WorkoutTemplateExerciseOption = { payload in
            try await WorkoutTemplateAPIClient.live.createExerciseOption(payload)
        }
    ) {
        self.session = session
        self.workoutTemplate = workoutTemplate
        self.store = store
        self.getWorkoutSession = getWorkoutSession
        self.updateWorkoutSession = updateWorkoutSession
        self.updateWorkoutSessionExercise = updateWorkoutSessionExercise
        self.updateWorkoutSessionSet = updateWorkoutSessionSet
        self.createExerciseOption = createExerciseOption
        self.now = now

        if let state = try? store.load(), state.session.id == session.id {
            self.session = state.session
            pendingSetUpdates = state.pendingSetUpdates
            pendingSessionUpdate = state.pendingSessionUpdate
            refreshPendingSyncCount()
            syncIssues = state.syncIssues
            syncIssueCount = state.syncIssues.count
        } else {
            self.session = session
        }

        selectedExerciseID = self.session.exercises.sortedByPosition.first?.id
        prepareDraftForCurrentSet()
    }

    var selectedExercise: WorkoutSessionExercise? {
        guard let selectedExerciseID else {
            return nil
        }

        return session.exercises.first { $0.id == selectedExerciseID }
    }

    var currentSet: WorkoutSessionSet? {
        selectedExercise?.workoutSessionSets.sortedByPosition.first { $0.completionState == .pending }
    }

    var isSessionComplete: Bool {
        session.exercises.allSatisfy { exercise in
            exercise.workoutSessionSets.allSatisfy { $0.completionState != .pending }
        }
    }

    var substitutionOptions: [WorkoutTemplateExerciseOption] {
        guard let selectedExercise,
              let workoutTemplateSlotID = selectedExercise.workoutTemplateSlotID,
              let slot = workoutTemplate?.slots.first(where: { $0.id == workoutTemplateSlotID }) else {
            return []
        }

        return slot.exerciseOptions
            .filter { option in
                option.exerciseID != selectedExercise.selectedExerciseID && option.exercise.archivedAt == nil
            }
            .sorted { $0.position < $1.position }
    }

    var canModifySelectedExercise: Bool {
        guard session.status == .active,
              let selectedExercise,
              selectedExercise.workoutTemplateSlotID != nil else {
            return false
        }

        return selectedExercise.workoutSessionSets.allSatisfy { $0.completionState == .pending }
    }

    func selectExercise(_ exercise: WorkoutSessionExercise) {
        selectedExerciseID = exercise.id
        prepareDraftForCurrentSet()
    }

    func incrementReps() {
        let currentValue = Int(repDraft) ?? 0
        repDraft = String(currentValue + 1)
    }

    func decrementReps() {
        let currentValue = Int(repDraft) ?? 0
        repDraft = String(max(currentValue - 1, 0))
    }

    func saveCurrentSet() async -> Bool {
        guard let exerciseIndex = selectedExerciseIndex,
              let setIndex = currentSetIndex,
              let actualReps = Int(repDraft),
              actualReps > 0 else {
            errorMessage = "Enter reps before saving."
            return false
        }

        errorMessage = nil

        var updatedSession = session
        let completedAt = now()
        var updatedSet = updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex]
        let actualLoad: Double?

        do {
            actualLoad = try actualLoadValue(plannedLoad: updatedSet.plannedLoadValue)
        } catch {
            errorMessage = "Enter a valid load."
            return false
        }
        let completedAtTimestamp = completedAt.apiTimestamp
        let completionState = completionState(actualReps: actualReps, targetRepMin: updatedSet.targetRepMin)
        let pendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: updatedSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: actualReps,
                actualLoadValue: actualLoad,
                completionState: completionState,
                completedAt: completedAtTimestamp,
                lockVersion: updatedSet.lockVersion
            )
        )
        let updatedPendingSetUpdates = pendingSetUpdates.upserting(pendingUpdate)
        let updatedSyncIssues = syncIssues.removing(setID: pendingUpdate.setID)

        updatedSet.actualReps = actualReps
        updatedSet.actualLoadValue = actualLoad
        updatedSet.completionState = completionState
        updatedSet.completedAt = completedAtTimestamp
        updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex] = updatedSet

        do {
            try store.save(
                ActiveWorkoutState(
                    session: updatedSession,
                    pendingSetUpdates: updatedPendingSetUpdates,
                    pendingSessionUpdate: pendingSessionUpdate,
                    syncIssues: updatedSyncIssues
                )
            )
        } catch {
            errorMessage = "Could not save set."
            return false
        }

        session = updatedSession
        pendingSetUpdates = updatedPendingSetUpdates
        syncIssues = updatedSyncIssues
        restEndsAt = completedAt.addingTimeInterval(TimeInterval(updatedSession.exercises[exerciseIndex].restSeconds))
        prepareDraftForCurrentSet()
        await retryPendingSync()

        return true
    }

    func finishWorkout() async -> Bool {
        errorMessage = nil

        let finishedAt = now()
        let completedAtTimestamp = finishedAt.apiTimestamp
        let updatedSession = session.finishingIncompleteWorkout(completedAt: completedAtTimestamp)
        let pendingUpdate = PendingWorkoutSessionUpdate(
            sessionID: updatedSession.id,
            payload: WorkoutSessionStatusPayload(
                status: .completed,
                completedAt: completedAtTimestamp,
                lockVersion: session.lockVersion
            )
        )

        do {
            try store.save(
                ActiveWorkoutState(
                    session: updatedSession,
                    pendingSetUpdates: pendingSetUpdates,
                    pendingSessionUpdate: pendingUpdate,
                    syncIssues: syncIssues
                )
            )
        } catch {
            errorMessage = "Could not finish workout."
            return false
        }

        session = updatedSession
        pendingSessionUpdate = pendingUpdate
        prepareDraftForCurrentSet()
        await retryPendingSync()
        return true
    }

    func skipSelectedExercise() async -> Bool {
        guard session.status == .active,
              let exerciseIndex = selectedExerciseIndex else {
            return false
        }

        let pendingSetIndices = session.exercises[exerciseIndex].workoutSessionSets.indices.filter { index in
            session.exercises[exerciseIndex].workoutSessionSets[index].completionState == .pending
        }
        guard !pendingSetIndices.isEmpty else {
            errorMessage = "Exercise has no remaining sets."
            return false
        }

        var updatedSession = session
        var updatedPendingSetUpdates = pendingSetUpdates
        var updatedSyncIssues = syncIssues

        for setIndex in pendingSetIndices {
            let set = updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex]
            updatedPendingSetUpdates = updatedPendingSetUpdates.upserting(
                PendingWorkoutSessionSetUpdate(
                    setID: set.id,
                    payload: WorkoutSessionSetUpdatePayload(
                        actualReps: nil,
                        actualLoadValue: nil,
                        completionState: .notPerformed,
                        completedAt: nil,
                        lockVersion: set.lockVersion
                    )
                )
            )
            updatedSyncIssues = updatedSyncIssues.removing(setID: set.id)
            updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].actualReps = nil
            updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].actualLoadValue = nil
            updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].completionState = .notPerformed
            updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].completedAt = nil
        }

        updatedSession.exercises[exerciseIndex].status = updatedSession.exercises[exerciseIndex]
            .workoutSessionSets
            .contains { $0.completionState.isPerformed } ? .completed : .skipped

        do {
            try store.save(
                ActiveWorkoutState(
                    session: updatedSession,
                    pendingSetUpdates: updatedPendingSetUpdates,
                    pendingSessionUpdate: pendingSessionUpdate,
                    syncIssues: updatedSyncIssues
                )
            )
        } catch {
            errorMessage = "Could not skip exercise."
            return false
        }

        session = updatedSession
        pendingSetUpdates = updatedPendingSetUpdates
        syncIssues = updatedSyncIssues
        restEndsAt = nil
        prepareDraftForCurrentSet()
        await retryPendingSync()
        return true
    }

    func cancelWorkout() async -> Bool {
        guard session.status == .active else {
            return false
        }

        errorMessage = nil
        let canceledAtTimestamp = now().apiTimestamp
        let updatedSession = session.cancelingWorkout(canceledAt: canceledAtTimestamp)
        let pendingUpdate = PendingWorkoutSessionUpdate(
            sessionID: updatedSession.id,
            payload: WorkoutSessionStatusPayload(
                status: .canceled,
                completedAt: nil,
                canceledAt: canceledAtTimestamp,
                lockVersion: session.lockVersion
            )
        )

        do {
            try store.save(
                ActiveWorkoutState(
                    session: updatedSession,
                    pendingSetUpdates: pendingSetUpdates,
                    pendingSessionUpdate: pendingUpdate,
                    syncIssues: syncIssues
                )
            )
        } catch {
            errorMessage = "Could not cancel workout."
            return false
        }

        session = updatedSession
        pendingSessionUpdate = pendingUpdate
        restEndsAt = nil
        prepareDraftForCurrentSet()
        await retryPendingSync()
        return true
    }

    func substituteSelectedExercise(with option: WorkoutTemplateExerciseOption) async -> Bool {
        guard canModifySelectedExercise,
              let selectedExercise else {
            errorMessage = "Exercise cannot be changed after logging a set."
            return false
        }

        errorMessage = nil

        do {
            let updatedExercise = try await updateWorkoutSessionExercise(
                selectedExercise.id,
                WorkoutSessionExerciseUpdatePayload(
                    workoutTemplateExerciseOptionID: option.id,
                    lockVersion: selectedExercise.lockVersion
                )
            )
            let updatedSession = session.merging(updatedExercise)
            try store.save(
                ActiveWorkoutState(
                    session: updatedSession,
                    pendingSetUpdates: pendingSetUpdates,
                    pendingSessionUpdate: pendingSessionUpdate,
                    syncIssues: syncIssues
                )
            )
            session = updatedSession
            prepareDraftForCurrentSet()
            return true
        } catch {
            errorMessage = "Could not swap exercise."
            return false
        }
    }

    func addAndSelectSubstitute(
        form: ExerciseFormState,
        startingLoadValue: Double?,
        progressionIncrement: Double?
    ) async -> Bool {
        guard canModifySelectedExercise,
              let workoutTemplateSlotID = selectedExercise?.workoutTemplateSlotID else {
            errorMessage = "Exercise cannot be changed after logging a set."
            return false
        }

        errorMessage = nil

        do {
            let option = try await createExerciseOption(
                WorkoutTemplateExerciseOptionCreatePayload(
                    workoutTemplateSlotID: workoutTemplateSlotID,
                    exerciseID: nil,
                    exercise: form.payload(lockVersion: nil),
                    startingLoadValue: startingLoadValue,
                    progressionIncrement: progressionIncrement
                )
            )
            upsertExerciseOption(option, slotID: workoutTemplateSlotID)
            return await substituteSelectedExercise(with: option)
        } catch {
            errorMessage = "Could not add exercise."
            return false
        }
    }

    func retryPendingSync() async {
        await retryPendingSetUpdates()

        guard pendingSetUpdates.isEmpty else {
            return
        }

        guard syncIssues.isEmpty else {
            errorMessage = "Some set syncs need attention."
            return
        }

        await retryPendingSessionUpdate()
    }

    func retryPendingSetUpdates() async {
        guard !pendingSetUpdates.isEmpty else {
            return
        }

        var remainingUpdates = pendingSetUpdates
        var currentSyncIssues = syncIssues
        var hadTransientFailure = false

        for pendingUpdate in pendingSetUpdates {
            guard remainingUpdates.contains(where: { $0.setID == pendingUpdate.setID }) else {
                continue
            }

            do {
                let syncedSet = try await syncPendingSetUpdate(pendingUpdate)
                let nextRemainingUpdates = remainingUpdates.filter { $0.setID != pendingUpdate.setID }
                let nextSyncIssues = currentSyncIssues.removing(setID: pendingUpdate.setID)
                let updatedSession = session.merging(syncedSet)

                try store.save(
                    ActiveWorkoutState(
                        session: updatedSession,
                        pendingSetUpdates: nextRemainingUpdates,
                        pendingSessionUpdate: pendingSessionUpdate,
                        syncIssues: nextSyncIssues
                    )
                )
                session = updatedSession
                remainingUpdates = nextRemainingUpdates
                currentSyncIssues = nextSyncIssues
                pendingSetUpdates = remainingUpdates
                syncIssues = currentSyncIssues
            } catch {
                if error.isNonRetryableSyncFailure {
                    let nextRemainingUpdates = remainingUpdates.filter { $0.setID != pendingUpdate.setID }
                    let nextSyncIssues = currentSyncIssues.upserting(
                        WorkoutSessionSetSyncIssue(
                            setID: pendingUpdate.setID,
                            payload: pendingUpdate.payload,
                            statusCode: error.workoutSessionStatusCode
                        )
                    )

                    do {
                        try store.save(
                            ActiveWorkoutState(
                                session: session,
                                pendingSetUpdates: nextRemainingUpdates,
                                pendingSessionUpdate: pendingSessionUpdate,
                                syncIssues: nextSyncIssues
                            )
                        )
                        remainingUpdates = nextRemainingUpdates
                        currentSyncIssues = nextSyncIssues
                        pendingSetUpdates = remainingUpdates
                        syncIssues = currentSyncIssues
                    } catch {
                        hadTransientFailure = true
                    }
                } else {
                    hadTransientFailure = true
                }
            }
        }

        if !currentSyncIssues.isEmpty {
            errorMessage = "Some set syncs need attention."
        } else if hadTransientFailure {
            errorMessage = "Set saved locally. Sync pending."
        } else {
            errorMessage = nil
        }
    }

    func retryPendingSessionUpdate() async {
        guard let pendingSessionUpdate else {
            return
        }

        do {
            let syncedSession = try await syncPendingSessionUpdate(pendingSessionUpdate)

            try store.save(
                ActiveWorkoutState(
                    session: syncedSession,
                    pendingSetUpdates: pendingSetUpdates,
                    syncIssues: syncIssues
                )
            )

            session = syncedSession
            self.pendingSessionUpdate = nil
            prepareDraftForCurrentSet()

            if pendingSetUpdates.isEmpty && syncIssues.isEmpty {
                do {
                    try store.clear()
                } catch {
                    errorMessage = "Could not clear active workout."
                    return
                }
            }

            errorMessage = nil
        } catch ActiveWorkoutStatusSyncError.needsAttention {
            errorMessage = "Workout \(pendingSessionUpdate.payload.actionName) sync needs attention."
        } catch {
            errorMessage = "Workout saved locally. \(pendingSessionUpdate.payload.actionName.capitalized) sync pending."
        }
    }

    func completedSetCount(for exercise: WorkoutSessionExercise) -> Int {
        exercise.workoutSessionSets.filter { $0.completionState != .pending }.count
    }

    private var selectedExerciseIndex: Int? {
        guard let selectedExerciseID else {
            return nil
        }

        return session.exercises.firstIndex { $0.id == selectedExerciseID }
    }

    private var currentSetIndex: Int? {
        guard let selectedExerciseIndex else {
            return nil
        }

        let currentPendingSet = session.exercises[selectedExerciseIndex]
            .workoutSessionSets
            .sortedByPosition
            .first { $0.completionState == .pending }

        guard let currentPendingSet else {
            return nil
        }

        return session.exercises[selectedExerciseIndex].workoutSessionSets.firstIndex { $0.id == currentPendingSet.id }
    }

    private func completionState(actualReps: Int, targetRepMin: Int) -> WorkoutSessionSetCompletionState {
        actualReps >= targetRepMin ? .completed : .attemptedButTargetNotMet
    }

    private func refreshPendingSyncCount() {
        pendingSyncCount = pendingSetUpdates.count + (pendingSessionUpdate == nil ? 0 : 1)
    }

    private func syncPendingSetUpdate(_ pendingUpdate: PendingWorkoutSessionSetUpdate) async throws -> WorkoutSessionSet {
        do {
            return try await updateWorkoutSessionSet(pendingUpdate.setID, pendingUpdate.payload)
        } catch let error as WorkoutSessionAPIError where error.isStaleConflict {
            let refreshedSession = try await getWorkoutSession(session.id)

            guard let refreshedSet = refreshedSession.set(id: pendingUpdate.setID) else {
                throw ActiveWorkoutSyncError.setMissingFromServer
            }

            if refreshedSet.matches(pendingUpdate.payload) {
                return refreshedSet
            }

            guard refreshedSet.canAcceptPendingSync else {
                throw ActiveWorkoutSyncError.conflict(statusCode: 409)
            }

            var refreshedPayload = pendingUpdate.payload
            refreshedPayload.lockVersion = refreshedSet.lockVersion

            return try await updateWorkoutSessionSet(pendingUpdate.setID, refreshedPayload)
        }
    }

    private func syncPendingSessionUpdate(_ pendingUpdate: PendingWorkoutSessionUpdate) async throws -> WorkoutSession {
        do {
            return try await updateWorkoutSession(
                pendingUpdate.sessionID,
                pendingUpdate.payload
            )
        } catch let error as WorkoutSessionAPIError where error.isStaleConflict {
            let refreshedSession = try await getWorkoutSession(pendingUpdate.sessionID)

            guard refreshedSession.matches(pendingUpdate.payload) else {
                throw ActiveWorkoutStatusSyncError.needsAttention
            }

            return refreshedSession
        } catch {
            if error.isNonRetryableSyncFailure {
                throw ActiveWorkoutStatusSyncError.needsAttention
            }

            throw error
        }
    }

    private func prepareDraftForCurrentSet() {
        guard let currentSet else {
            repDraft = ""
            loadDraft = ""
            return
        }

        repDraft = String(currentSet.actualReps ?? currentSet.targetRepMax)
        loadDraft = currentSet.actualLoadValue?.draftString ?? currentSet.plannedLoadValue?.draftString ?? ""
    }

    private func actualLoadValue(plannedLoad: Double?) throws -> Double? {
        let trimmedLoad = loadDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLoad.isEmpty else {
            return plannedLoad
        }

        guard let load = Double(trimmedLoad), load >= 0 else {
            throw ActiveWorkoutValidationError.invalidLoad
        }

        return load
    }

    private func upsertExerciseOption(_ option: WorkoutTemplateExerciseOption, slotID: UUID) {
        guard var template = workoutTemplate,
              let slotIndex = template.slots.firstIndex(where: { $0.id == slotID }) else {
            return
        }

        if let optionIndex = template.slots[slotIndex].exerciseOptions.firstIndex(where: { $0.id == option.id }) {
            template.slots[slotIndex].exerciseOptions[optionIndex] = option
        } else {
            template.slots[slotIndex].exerciseOptions.append(option)
        }

        workoutTemplate = template
    }
}

private enum ActiveWorkoutValidationError: Error {
    case invalidLoad
}

private enum ActiveWorkoutSyncError: Error {
    case conflict(statusCode: Int)
    case setMissingFromServer
}

private enum ActiveWorkoutStatusSyncError: Error {
    case needsAttention
}

private extension Error {
    var workoutSessionStatusCode: Int? {
        if let error = self as? ActiveWorkoutSyncError {
            return error.statusCode
        }

        guard let error = self as? WorkoutSessionAPIError,
              case let .requestFailed(statusCode) = error else {
            return nil
        }

        return statusCode
    }

    var isNonRetryableSyncFailure: Bool {
        if self is ActiveWorkoutSyncError {
            return true
        }

        guard let statusCode = workoutSessionStatusCode else {
            return false
        }

        return statusCode == 409 || statusCode == 422
    }
}

private extension ActiveWorkoutSyncError {
    var statusCode: Int? {
        switch self {
        case let .conflict(statusCode):
            statusCode
        case .setMissingFromServer:
            nil
        }
    }
}

private extension WorkoutSessionAPIError {
    var isStaleConflict: Bool {
        self == .requestFailed(statusCode: 409)
    }
}

private extension WorkoutSession {
    func set(id: UUID) -> WorkoutSessionSet? {
        for exercise in exercises {
            if let set = exercise.workoutSessionSets.first(where: { $0.id == id }) {
                return set
            }
        }

        return nil
    }

    func merging(_ syncedSet: WorkoutSessionSet) -> WorkoutSession {
        var updatedSession = self

        for exerciseIndex in updatedSession.exercises.indices {
            guard let setIndex = updatedSession.exercises[exerciseIndex].workoutSessionSets.firstIndex(where: { $0.id == syncedSet.id }) else {
                continue
            }

            updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex] = syncedSet
            return updatedSession
        }

        return updatedSession
    }

    func merging(_ syncedExercise: WorkoutSessionExercise) -> WorkoutSession {
        var updatedSession = self

        guard let exerciseIndex = updatedSession.exercises.firstIndex(where: { $0.id == syncedExercise.id }) else {
            return updatedSession
        }

        updatedSession.exercises[exerciseIndex] = syncedExercise
        return updatedSession
    }

    func finishingIncompleteWorkout(completedAt: String) -> WorkoutSession {
        var updatedSession = self
        updatedSession.status = .completed
        updatedSession.completedAt = completedAt
        updatedSession.canceledAt = nil

        for exerciseIndex in updatedSession.exercises.indices {
            for setIndex in updatedSession.exercises[exerciseIndex].workoutSessionSets.indices {
                guard updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].completionState == .pending else {
                    continue
                }

                updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].actualReps = nil
                updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].actualLoadValue = nil
                updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].completionState = .notPerformed
                updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].completedAt = nil
            }

            updatedSession.exercises[exerciseIndex].status = updatedSession.exercises[exerciseIndex].workoutSessionSets.contains { $0.completionState.isPerformed } ? .completed : .skipped
        }

        return updatedSession
    }

    func cancelingWorkout(canceledAt: String) -> WorkoutSession {
        var updatedSession = self
        updatedSession.status = .canceled
        updatedSession.completedAt = nil
        updatedSession.canceledAt = canceledAt
        return updatedSession
    }

    func matches(_ payload: WorkoutSessionStatusPayload) -> Bool {
        status == payload.status &&
            completedAt == payload.completedAt &&
            canceledAt == payload.canceledAt
    }
}

private extension WorkoutSessionStatusPayload {
    var actionName: String {
        status == .canceled ? "cancel" : "finish"
    }
}

private extension WorkoutSessionSet {
    var canAcceptPendingSync: Bool {
        completionState == .pending &&
            actualReps == nil &&
            actualLoadValue == nil &&
            completedAt == nil
    }

    func matches(_ payload: WorkoutSessionSetUpdatePayload) -> Bool {
        actualReps == payload.actualReps &&
            actualLoadValue == payload.actualLoadValue &&
            completionState == payload.completionState &&
            completedAt == payload.completedAt
    }
}

private extension Array where Element == WorkoutSessionExercise {
    var sortedByPosition: [WorkoutSessionExercise] {
        sorted { $0.position < $1.position }
    }
}

private extension Array where Element == WorkoutSessionSet {
    var sortedByPosition: [WorkoutSessionSet] {
        sorted { $0.position < $1.position }
    }
}

private extension Array where Element == PendingWorkoutSessionSetUpdate {
    func upserting(_ update: PendingWorkoutSessionSetUpdate) -> [PendingWorkoutSessionSetUpdate] {
        var updates = self

        if let index = updates.firstIndex(where: { $0.setID == update.setID }) {
            updates[index] = update
        } else {
            updates.append(update)
        }

        return updates
    }

    func removing(setID: UUID) -> [PendingWorkoutSessionSetUpdate] {
        filter { $0.setID != setID }
    }
}

private extension Array where Element == WorkoutSessionSetSyncIssue {
    func upserting(_ issue: WorkoutSessionSetSyncIssue) -> [WorkoutSessionSetSyncIssue] {
        var issues = self

        if let index = issues.firstIndex(where: { $0.setID == issue.setID }) {
            issues[index] = issue
        } else {
            issues.append(issue)
        }

        return issues
    }

    func removing(setID: UUID) -> [WorkoutSessionSetSyncIssue] {
        filter { $0.setID != setID }
    }
}

private extension Date {
    var apiTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}

private extension Double {
    var draftString: String {
        return String(self)
    }
}
