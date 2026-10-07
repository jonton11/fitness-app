import Foundation

struct WorkoutHistoryEntry: Equatable, Identifiable {
    enum SyncState: Equatable {
        case pending
        case needsAttention
    }

    var session: WorkoutSession
    var syncState: SyncState?

    var id: UUID {
        session.id
    }
}

@MainActor
final class WorkoutHistoryViewModel: ObservableObject {
    @Published private(set) var entries: [WorkoutHistoryEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let activeWorkoutStore: ActiveWorkoutStore
    private let listWorkoutSessions: () async throws -> [WorkoutSession]

    init(
        activeWorkoutStore: ActiveWorkoutStore = .live,
        listWorkoutSessions: @escaping () async throws -> [WorkoutSession] = {
            try await WorkoutSessionAPIClient.live.listWorkoutSessions()
        }
    ) {
        self.activeWorkoutStore = activeWorkoutStore
        self.listWorkoutSessions = listWorkoutSessions
    }

    func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        let localEntry: WorkoutHistoryEntry?
        var storeErrorMessage: String?

        do {
            localEntry = try pendingLocalEntry()
        } catch {
            localEntry = nil
            storeErrorMessage = "Could not load the workout awaiting sync."
        }

        do {
            let sessions = try await listWorkoutSessions()
            entries = merge(localEntry: localEntry, serverSessions: sessions)
            errorMessage = storeErrorMessage
        } catch {
            let previouslyLoadedSessions = entries
                .filter { $0.syncState == nil }
                .map(\.session)
            entries = merge(localEntry: localEntry, serverSessions: previouslyLoadedSessions)
            errorMessage = storeErrorMessage ?? "Could not refresh workout history."
        }
    }

    private func pendingLocalEntry() throws -> WorkoutHistoryEntry? {
        guard let state = try activeWorkoutStore.load(),
              state.session.status == .completed else {
            return nil
        }

        let syncState: WorkoutHistoryEntry.SyncState?

        if !state.syncIssues.isEmpty {
            syncState = .needsAttention
        } else if state.pendingSessionCreation != nil ||
                    !state.pendingSetUpdates.isEmpty ||
                    state.pendingSessionUpdate != nil {
            syncState = .pending
        } else {
            syncState = nil
        }

        guard let syncState else {
            return nil
        }

        return WorkoutHistoryEntry(session: state.session, syncState: syncState)
    }

    private func merge(
        localEntry: WorkoutHistoryEntry?,
        serverSessions: [WorkoutSession]
    ) -> [WorkoutHistoryEntry] {
        var mergedEntries = serverSessions.map {
            WorkoutHistoryEntry(session: $0, syncState: nil)
        }

        if let localEntry {
            mergedEntries.removeAll { $0.id == localEntry.id }
            mergedEntries.append(localEntry)
        }

        return mergedEntries.sorted {
            $0.session.startedAt > $1.session.startedAt
        }
    }
}
