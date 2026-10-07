import Foundation
import SwiftData

@Model
final class LocalDocument {
    @Attribute(.unique) var key: String
    var data: Data

    init(key: String, data: Data) {
        self.key = key
        self.data = data
    }
}

final class FitnessLocalDatabase: @unchecked Sendable {
    static let shared: FitnessLocalDatabase = {
        do {
            return try FitnessLocalDatabase()
        } catch {
            fatalError("Could not initialize local storage: \(error)")
        }
    }()

    private let container: ModelContainer
    private let lock = NSLock()

    init(isStoredInMemoryOnly: Bool = false) throws {
        let schema = Schema([LocalDocument.self])
        let configuration = ModelConfiguration(
            "FitnessLocal",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    func data(forKey key: String) throws -> Data? {
        try withLock {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<LocalDocument>(
                predicate: #Predicate { document in
                    document.key == key
                }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.data
        }
    }

    func save(_ data: Data, forKey key: String) throws {
        try withLock {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<LocalDocument>(
                predicate: #Predicate { document in
                    document.key == key
                }
            )
            descriptor.fetchLimit = 1

            if let document = try context.fetch(descriptor).first {
                document.data = data
            } else {
                context.insert(LocalDocument(key: key, data: data))
            }

            try context.save()
        }
    }

    func deleteValue(forKey key: String) throws {
        try withLock {
            let context = ModelContext(container)
            try context.delete(model: LocalDocument.self, where: #Predicate { document in
                document.key == key
            })
            try context.save()
        }
    }

    private func withLock<Result>(_ operation: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try operation()
    }
}
