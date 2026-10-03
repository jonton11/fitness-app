import Foundation

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    @Published private(set) var session: WorkoutSession
    @Published private(set) var selectedExerciseID: UUID?
    @Published var repDraft = ""
    @Published var loadDraft = ""
    @Published var errorMessage: String?
    @Published private(set) var restEndsAt: Date?
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var syncIssueCount = 0

    private let store: ActiveWorkoutStore
    private let getWorkoutSession: (UUID) async throws -> WorkoutSession
    private let updateWorkoutSessionSet: (UUID, WorkoutSessionSetUpdatePayload) async throws -> WorkoutSessionSet
    private let now: () -> Date
    private var pendingSetUpdates: [PendingWorkoutSessionSetUpdate] = [] {
        didSet {
            pendingSyncCount = pendingSetUpdates.count
        }
    }
    private var syncIssues: [WorkoutSessionSetSyncIssue] = [] {
        didSet {
            syncIssueCount = syncIssues.count
        }
    }

    init(
        session: WorkoutSession,
        store: ActiveWorkoutStore = .live,
        now: @escaping () -> Date = Date.init,
        getWorkoutSession: @escaping (UUID) async throws -> WorkoutSession = { id in
            try await WorkoutSessionAPIClient.live.getWorkoutSession(id: id)
        },
        updateWorkoutSessionSet: @escaping (UUID, WorkoutSessionSetUpdatePayload) async throws -> WorkoutSessionSet = { id, payload in
            try await WorkoutSessionAPIClient.live.updateWorkoutSessionSet(id: id, payload: payload)
        }
    ) {
        self.session = session
        self.store = store
        self.getWorkoutSession = getWorkoutSession
        self.updateWorkoutSessionSet = updateWorkoutSessionSet
        self.now = now

        if let state = try? store.load(), state.session.id == session.id {
            self.session = state.session
            pendingSetUpdates = state.pendingSetUpdates
            pendingSyncCount = state.pendingSetUpdates.count
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
        await retryPendingSetUpdates()

        return true
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
}

private enum ActiveWorkoutValidationError: Error {
    case invalidLoad
}

private enum ActiveWorkoutSyncError: Error {
    case conflict(statusCode: Int)
    case setMissingFromServer
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
