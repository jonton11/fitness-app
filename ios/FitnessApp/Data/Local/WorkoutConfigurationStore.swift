import Foundation

struct WorkoutConfigurationStore: Sendable {
    var load: @Sendable () throws -> WorkoutConfigurationSnapshot?
    var save: @Sendable (WorkoutConfigurationSnapshot) throws -> Void

    static let live = WorkoutConfigurationStore(database: .shared)

    init(
        load: @escaping @Sendable () throws -> WorkoutConfigurationSnapshot?,
        save: @escaping @Sendable (WorkoutConfigurationSnapshot) throws -> Void
    ) {
        self.load = load
        self.save = save
    }

    init(database: FitnessLocalDatabase) {
        load = {
            guard let data = try database.data(forKey: WorkoutConfigurationSnapshot.storageKey) else {
                return nil
            }
            return try JSONDecoder().decode(WorkoutConfigurationSnapshot.self, from: data)
        }
        save = { snapshot in
            try database.save(
                JSONEncoder().encode(snapshot),
                forKey: WorkoutConfigurationSnapshot.storageKey
            )
        }
    }
}

struct WorkoutConfigurationSnapshot: Codable, Equatable {
    fileprivate static let storageKey = "workout_configuration"

    var templates: [WorkoutTemplate]
    var exercises: [Exercise]
}
