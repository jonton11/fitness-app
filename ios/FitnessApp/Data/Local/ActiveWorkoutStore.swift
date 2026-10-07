import Foundation

struct ActiveWorkoutStore: Sendable {
    var load: @Sendable () throws -> ActiveWorkoutState?
    var save: @Sendable (ActiveWorkoutState) throws -> Void
    var clear: @Sendable () throws -> Void

    static let live = ActiveWorkoutStore(database: .shared)

    init(
        load: @escaping @Sendable () throws -> ActiveWorkoutState?,
        save: @escaping @Sendable (ActiveWorkoutState) throws -> Void,
        clear: @escaping @Sendable () throws -> Void
    ) {
        self.load = load
        self.save = save
        self.clear = clear
    }

    init(database: FitnessLocalDatabase, legacyFileURL: URL? = ActiveWorkoutStore.legacyFileURL()) {
        load = {
            if let data = try database.data(forKey: ActiveWorkoutState.storageKey) {
                return try ActiveWorkoutStore.decodeState(from: data)
            }

            guard let legacyFileURL,
                  FileManager.default.fileExists(atPath: legacyFileURL.path) else {
                return nil
            }

            let state = try ActiveWorkoutStore.decodeState(from: Data(contentsOf: legacyFileURL))
            try database.save(JSONEncoder().encode(state), forKey: ActiveWorkoutState.storageKey)
            try FileManager.default.removeItem(at: legacyFileURL)
            return state
        }
        save = { state in
            try database.save(
                JSONEncoder().encode(state),
                forKey: ActiveWorkoutState.storageKey
            )
        }
        clear = {
            try database.deleteValue(forKey: ActiveWorkoutState.storageKey)
        }
    }

    private static func decodeState(from data: Data) throws -> ActiveWorkoutState {
        let decoder = JSONDecoder()

        if let state = try? decoder.decode(ActiveWorkoutState.self, from: data) {
            return state
        }

        return try ActiveWorkoutState(session: decoder.decode(WorkoutSession.self, from: data))
    }

    private static func legacyFileURL() -> URL? {
        guard let directoryURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return directoryURL
            .appending(path: "FitnessApp")
            .appending(path: "active_workout_session.json")
    }
}

struct ActiveWorkoutState: Codable, Equatable {
    fileprivate static let storageKey = "active_workout"

    var session: WorkoutSession
    var workoutTemplate: WorkoutTemplate?
    var pendingSessionCreation: PendingWorkoutSessionCreation?
    var pendingSetUpdates: [PendingWorkoutSessionSetUpdate]
    var pendingSessionUpdate: PendingWorkoutSessionUpdate?
    var syncIssues: [WorkoutSessionSetSyncIssue]

    init(
        session: WorkoutSession,
        workoutTemplate: WorkoutTemplate? = nil,
        pendingSessionCreation: PendingWorkoutSessionCreation? = nil,
        pendingSetUpdates: [PendingWorkoutSessionSetUpdate] = [],
        pendingSessionUpdate: PendingWorkoutSessionUpdate? = nil,
        syncIssues: [WorkoutSessionSetSyncIssue] = []
    ) {
        self.session = session
        self.workoutTemplate = workoutTemplate
        self.pendingSessionCreation = pendingSessionCreation
        self.pendingSetUpdates = pendingSetUpdates
        self.pendingSessionUpdate = pendingSessionUpdate
        self.syncIssues = syncIssues
    }

    enum CodingKeys: String, CodingKey {
        case session
        case workoutTemplate = "workout_template"
        case pendingSessionCreation = "pending_session_creation"
        case pendingSetUpdates = "pending_set_updates"
        case pendingSessionUpdate = "pending_session_update"
        case syncIssues = "sync_issues"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case pendingSessionCompletion = "pending_session_completion"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        session = try container.decode(WorkoutSession.self, forKey: .session)
        workoutTemplate = try container.decodeIfPresent(WorkoutTemplate.self, forKey: .workoutTemplate)
        pendingSessionCreation = try container.decodeIfPresent(
            PendingWorkoutSessionCreation.self,
            forKey: .pendingSessionCreation
        )
        pendingSetUpdates = try container.decodeIfPresent(
            [PendingWorkoutSessionSetUpdate].self,
            forKey: .pendingSetUpdates
        ) ?? []
        let currentPendingSessionUpdate = try container.decodeIfPresent(
            PendingWorkoutSessionUpdate.self,
            forKey: .pendingSessionUpdate
        )
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        pendingSessionUpdate = try currentPendingSessionUpdate ?? legacyContainer.decodeIfPresent(
            PendingWorkoutSessionUpdate.self,
            forKey: .pendingSessionCompletion
        )
        syncIssues = try container.decodeIfPresent(
            [WorkoutSessionSetSyncIssue].self,
            forKey: .syncIssues
        ) ?? []
    }
}

struct PendingWorkoutSessionCreation: Codable, Equatable, Identifiable {
    var payload: WorkoutSessionCreatePayload

    var id: UUID {
        payload.id
    }
}

struct PendingWorkoutSessionSetUpdate: Codable, Equatable, Identifiable {
    var setID: UUID
    var payload: WorkoutSessionSetUpdatePayload

    var id: UUID {
        setID
    }

    enum CodingKeys: String, CodingKey {
        case setID = "set_id"
        case payload
    }
}

struct PendingWorkoutSessionUpdate: Codable, Equatable, Identifiable {
    var sessionID: UUID
    var payload: WorkoutSessionStatusPayload

    var id: UUID {
        sessionID
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case payload
    }
}

struct WorkoutSessionSetSyncIssue: Codable, Equatable, Identifiable {
    var setID: UUID
    var payload: WorkoutSessionSetUpdatePayload
    var statusCode: Int?

    var id: UUID {
        setID
    }

    enum CodingKeys: String, CodingKey {
        case setID = "set_id"
        case payload
        case statusCode = "status_code"
    }
}
