import Foundation

struct ActiveWorkoutStore: Sendable {
    var load: @Sendable () throws -> ActiveWorkoutState?
    var save: @Sendable (ActiveWorkoutState) throws -> Void
    var clear: @Sendable () throws -> Void

    static let live = ActiveWorkoutStore(
        load: {
            let fileURL = try activeWorkoutFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()

            if let state = try? decoder.decode(ActiveWorkoutState.self, from: data) {
                return state
            }

            return try ActiveWorkoutState(session: decoder.decode(WorkoutSession.self, from: data))
        },
        save: { state in
            let fileURL = try activeWorkoutFileURL()
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        },
        clear: {
            let fileURL = try activeWorkoutFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return
            }

            try FileManager.default.removeItem(at: fileURL)
        }
    )

    private static func activeWorkoutFileURL() throws -> URL {
        let directoryURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: "FitnessApp")

        return directoryURL.appending(path: "active_workout_session.json")
    }
}

struct ActiveWorkoutState: Codable, Equatable {
    var session: WorkoutSession
    var pendingSetUpdates: [PendingWorkoutSessionSetUpdate]
    var syncIssues: [WorkoutSessionSetSyncIssue]

    init(
        session: WorkoutSession,
        pendingSetUpdates: [PendingWorkoutSessionSetUpdate] = [],
        syncIssues: [WorkoutSessionSetSyncIssue] = []
    ) {
        self.session = session
        self.pendingSetUpdates = pendingSetUpdates
        self.syncIssues = syncIssues
    }

    enum CodingKeys: String, CodingKey {
        case session
        case pendingSetUpdates = "pending_set_updates"
        case syncIssues = "sync_issues"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        session = try container.decode(WorkoutSession.self, forKey: .session)
        pendingSetUpdates = try container.decodeIfPresent(
            [PendingWorkoutSessionSetUpdate].self,
            forKey: .pendingSetUpdates
        ) ?? []
        syncIssues = try container.decodeIfPresent(
            [WorkoutSessionSetSyncIssue].self,
            forKey: .syncIssues
        ) ?? []
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
