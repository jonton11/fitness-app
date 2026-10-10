import Foundation

struct RoutineSessionStartStore: Sendable {
    var load: @Sendable () throws -> RoutineSessionStartPayload?
    var save: @Sendable (RoutineSessionStartPayload) throws -> Void
    var clear: @Sendable () throws -> Void

    static let live = RoutineSessionStartStore(database: .shared)

    init(
        load: @escaping @Sendable () throws -> RoutineSessionStartPayload?,
        save: @escaping @Sendable (RoutineSessionStartPayload) throws -> Void,
        clear: @escaping @Sendable () throws -> Void
    ) {
        self.load = load
        self.save = save
        self.clear = clear
    }

    init(database: FitnessLocalDatabase) {
        load = {
            guard let data = try database.data(forKey: RoutineSessionStartStore.storageKey) else {
                return nil
            }
            return try JSONDecoder().decode(RoutineSessionStartPayload.self, from: data)
        }
        save = { payload in
            try database.save(
                JSONEncoder().encode(payload),
                forKey: RoutineSessionStartStore.storageKey
            )
        }
        clear = {
            try database.deleteValue(forKey: RoutineSessionStartStore.storageKey)
        }
    }

    private static let storageKey = "pending_routine_session_start"
}
