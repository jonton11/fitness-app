import Foundation

final class HealthSyncStore: @unchecked Sendable {
    static let live = HealthSyncStore(defaults: .standard)

    private enum Key {
        static let enabled = "fitness.health-sync.enabled"
        static let lastSyncedAt = "fitness.health-sync.last-synced-at"

        static func anchor(for kind: HealthMetricKind) -> String {
            "fitness.health-sync.anchor.\(kind.rawValue)"
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        defaults.bool(forKey: Key.enabled)
    }

    var lastSyncedAt: Date? {
        defaults.object(forKey: Key.lastSyncedAt) as? Date
    }

    func setEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Key.enabled)
    }

    func anchor(for kind: HealthMetricKind) -> Data? {
        defaults.data(forKey: Key.anchor(for: kind))
    }

    func saveAnchor(_ anchor: Data, for kind: HealthMetricKind) {
        defaults.set(anchor, forKey: Key.anchor(for: kind))
    }

    func saveLastSyncedAt(_ date: Date) {
        defaults.set(date, forKey: Key.lastSyncedAt)
    }

    func reset() {
        defaults.removeObject(forKey: Key.enabled)
        defaults.removeObject(forKey: Key.lastSyncedAt)
        HealthMetricKind.allCases.forEach { kind in
            defaults.removeObject(forKey: Key.anchor(for: kind))
        }
    }
}
