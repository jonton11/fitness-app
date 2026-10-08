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
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = false
    @Published var errorMessage: String?

    private let activeWorkoutStore: ActiveWorkoutStore
    private let listWorkoutSessions: (Int) async throws -> WorkoutSessionPage
    private var serverSessions: [WorkoutSession] = []
    private var nextOffset = 0

    init(
        activeWorkoutStore: ActiveWorkoutStore = .live,
        listWorkoutSessions: @escaping (Int) async throws -> WorkoutSessionPage = { offset in
            try await WorkoutSessionAPIClient.live.listWorkoutSessions(offset: offset)
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
            let page = try await listWorkoutSessions(0)
            serverSessions = page.sessions
            applyPagination(page)
            entries = merge(localEntry: localEntry, serverSessions: serverSessions)
            errorMessage = storeErrorMessage
        } catch {
            entries = merge(localEntry: localEntry, serverSessions: serverSessions)
            errorMessage = storeErrorMessage ?? "Could not refresh workout history."
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoading, !isLoadingMore else {
            return
        }

        isLoadingMore = true
        defer {
            isLoadingMore = false
        }

        do {
            let page = try await listWorkoutSessions(nextOffset)
            appendServerSessions(page.sessions)
            applyPagination(page)
            entries = merge(localEntry: try pendingLocalEntry(), serverSessions: serverSessions)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load more workout history."
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

    private func appendServerSessions(_ sessions: [WorkoutSession]) {
        let existingIDs = Set(serverSessions.map(\.id))
        serverSessions.append(contentsOf: sessions.filter { !existingIDs.contains($0.id) })
    }

    private func applyPagination(_ page: WorkoutSessionPage) {
        nextOffset = page.nextOffset
        canLoadMore = page.hasNextPage
    }
}
