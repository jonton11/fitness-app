import Foundation

@MainActor
final class RoutinesViewModel: ObservableObject {
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var activeSessions: [RoutineSession] = []
    @Published private(set) var isLoading = false
    @Published private(set) var startingRoutineID: UUID?
    @Published private(set) var updatingItemIDs: Set<UUID> = []
    @Published private(set) var completingSessionID: UUID?
    @Published var errorMessage: String?

    private let listRoutines: () async throws -> [Routine]
    private let listActiveSessions: () async throws -> RoutineSessionPage
    private let startRoutineSession: (RoutineSessionStartPayload) async throws -> RoutineSession
    private let updateRoutineSessionItem: (UUID, RoutineSessionItemUpdatePayload) async throws -> RoutineSessionItem
    private let completeRoutineSession: (UUID, RoutineSessionCompletionPayload) async throws -> RoutineSession
    private let now: () -> Date
    private let makeID: () -> UUID

    init(
        apiClient: RoutineAPIClient = .live,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        listRoutines = {
            try await apiClient.listRoutines()
        }
        listActiveSessions = {
            try await apiClient.listRoutineSessions(status: .active)
        }
        startRoutineSession = { payload in
            try await apiClient.startRoutineSession(payload: payload)
        }
        updateRoutineSessionItem = { id, payload in
            try await apiClient.updateRoutineSessionItem(id: id, payload: payload)
        }
        completeRoutineSession = { id, payload in
            try await apiClient.completeRoutineSession(id: id, payload: payload)
        }
        self.now = now
        self.makeID = makeID
    }

    init(
        listRoutines: @escaping () async throws -> [Routine],
        listActiveSessions: @escaping () async throws -> RoutineSessionPage,
        startRoutineSession: @escaping (RoutineSessionStartPayload) async throws -> RoutineSession,
        updateRoutineSessionItem: @escaping (UUID, RoutineSessionItemUpdatePayload) async throws -> RoutineSessionItem,
        completeRoutineSession: @escaping (UUID, RoutineSessionCompletionPayload) async throws -> RoutineSession,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.listRoutines = listRoutines
        self.listActiveSessions = listActiveSessions
        self.startRoutineSession = startRoutineSession
        self.updateRoutineSessionItem = updateRoutineSessionItem
        self.completeRoutineSession = completeRoutineSession
        self.now = now
        self.makeID = makeID
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
            routines = try await listRoutines()
            let activePage = try await listActiveSessions()
            self.activeSessions = activePage.sessions
        } catch {
            errorMessage = "Could not load routines."
        }
    }

    func start(routine: Routine) async -> RoutineSession? {
        startingRoutineID = routine.id
        errorMessage = nil
        defer {
            startingRoutineID = nil
        }

        let payload = RoutineSessionStartPayload(
            id: makeID(),
            routineID: routine.id,
            startedAt: now().apiTimestamp,
            items: routine.items
                .sorted { $0.position < $1.position }
                .map {
                    RoutineSessionItemStartPayload(
                        id: makeID(),
                        routineItemID: $0.id
                    )
                }
        )

        do {
            let session = try await startRoutineSession(payload)
            upsertActiveSession(session)
            return session
        } catch {
            errorMessage = "Could not start routine."
            return nil
        }
    }

    func toggle(itemID: UUID, in sessionID: UUID) async {
        guard let session = activeSessions.first(where: { $0.id == sessionID }),
              let item = session.items.first(where: { $0.id == itemID }),
              !updatingItemIDs.contains(itemID) else {
            return
        }

        updatingItemIDs.insert(itemID)
        errorMessage = nil
        defer {
            updatingItemIDs.remove(itemID)
        }

        let completed = !item.isCompleted
        let payload = RoutineSessionItemUpdatePayload(
            completed: completed,
            completedAt: completed ? now().apiTimestamp : nil,
            lockVersion: item.lockVersion
        )

        do {
            let updatedItem = try await updateRoutineSessionItem(itemID, payload)
            replaceItem(updatedItem, in: sessionID)
        } catch {
            errorMessage = "Could not update routine item."
        }
    }

    func complete(sessionID: UUID) async -> Bool {
        guard let session = activeSessions.first(where: { $0.id == sessionID }),
              session.items.allSatisfy(\.isCompleted),
              completingSessionID == nil else {
            return false
        }

        completingSessionID = sessionID
        errorMessage = nil
        defer {
            completingSessionID = nil
        }

        do {
            _ = try await completeRoutineSession(
                sessionID,
                RoutineSessionCompletionPayload(
                    status: .completed,
                    completedAt: now().apiTimestamp,
                    lockVersion: session.lockVersion
                )
            )
            activeSessions.removeAll { $0.id == sessionID }
            return true
        } catch {
            errorMessage = "Could not finish routine."
            return false
        }
    }

    private func upsertActiveSession(_ session: RoutineSession) {
        if let index = activeSessions.firstIndex(where: { $0.id == session.id }) {
            activeSessions[index] = session
        } else {
            activeSessions.insert(session, at: 0)
        }
    }

    private func replaceItem(_ item: RoutineSessionItem, in sessionID: UUID) {
        guard let sessionIndex = activeSessions.firstIndex(where: { $0.id == sessionID }),
              let itemIndex = activeSessions[sessionIndex].items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        activeSessions[sessionIndex].items[itemIndex] = item
    }
}
