import Foundation

@MainActor
final class HealthSyncViewModel: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var confirmationMessage: String?

    private let healthKitClient: HealthKitClient
    private let healthSyncStore: HealthSyncStore
    private let ingestMetrics: @Sendable (
        [HealthMetricUpload],
        [UUID]
    ) async throws -> HealthMetricIngestionResult
    private let now: @Sendable () -> Date
    private var syncGeneration = 0

    init(
        healthKitClient: HealthKitClient = .live,
        healthSyncStore: HealthSyncStore = .live,
        ingestMetrics: @escaping @Sendable (
            [HealthMetricUpload],
            [UUID]
        ) async throws -> HealthMetricIngestionResult = {
            try await HealthMetricAPIClient.live.ingest($0, deleting: $1)
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.healthKitClient = healthKitClient
        self.healthSyncStore = healthSyncStore
        self.ingestMetrics = ingestMetrics
        self.now = now
        isEnabled = healthSyncStore.isEnabled
        lastSyncedAt = healthSyncStore.lastSyncedAt
    }

    var isAvailable: Bool {
        healthKitClient.isAvailable()
    }

    var statusText: String {
        if !isAvailable {
            return "Unavailable"
        }
        if isSyncing {
            return "Syncing"
        }
        return isEnabled ? "Enabled" : "Off"
    }

    func setSyncEnabled(_ shouldEnable: Bool) async {
        if !shouldEnable {
            healthSyncStore.setEnabled(false)
            isEnabled = false
            errorMessage = nil
            confirmationMessage = nil
            return
        }

        await performSync(requestAuthorization: true)
    }

    func syncNow() async {
        await performSync(requestAuthorization: false)
    }

    func syncIfEnabled() async {
        guard isEnabled else {
            return
        }
        await performSync(requestAuthorization: false)
    }

    func resetForCredentialChange() {
        syncGeneration += 1
        healthSyncStore.reset()
        isEnabled = false
        isSyncing = false
        lastSyncedAt = nil
        errorMessage = nil
        confirmationMessage = nil
    }

    private func performSync(requestAuthorization: Bool) async {
        guard isAvailable, !isSyncing else {
            return
        }

        let generation = syncGeneration
        isSyncing = true
        errorMessage = nil
        confirmationMessage = nil
        defer {
            if generation == syncGeneration {
                isSyncing = false
            }
        }

        do {
            if requestAuthorization {
                try await healthKitClient.requestAuthorization()
                try ensureCurrentSync(generation)
                healthSyncStore.setEnabled(true)
                isEnabled = true
            }

            let counts = try await syncChanges(generation: generation)
            try ensureCurrentSync(generation)
            let syncedAt = now()
            healthSyncStore.saveLastSyncedAt(syncedAt)
            lastSyncedAt = syncedAt
            confirmationMessage = syncConfirmation(
                createdCount: counts.created,
                deletedCount: counts.deleted
            )
        } catch {
            guard generation == syncGeneration else {
                return
            }
            errorMessage = "Health sync failed. Try again."
        }
    }

    private func syncChanges(generation: Int) async throws -> (created: Int, deleted: Int) {
        var createdCount = 0
        var deletedCount = 0

        for kind in HealthMetricKind.allCases {
            var anchor = healthSyncStore.anchor(for: kind)
            var hasMore = false

            repeat {
                let batch = try await healthKitClient.changes(kind, anchor)
                try ensureCurrentSync(generation)
                if !batch.metrics.isEmpty || !batch.deletedMetricIDs.isEmpty {
                    let result = try await ingestMetrics(batch.metrics, batch.deletedMetricIDs)
                    try ensureCurrentSync(generation)
                    createdCount += result.createdCount
                    deletedCount += result.deletedCount
                }

                if let nextAnchor = batch.nextAnchor {
                    try ensureCurrentSync(generation)
                    healthSyncStore.saveAnchor(nextAnchor, for: kind)
                    anchor = nextAnchor
                }
                hasMore = batch.hasMore
            } while hasMore
        }

        return (createdCount, deletedCount)
    }

    private func ensureCurrentSync(_ generation: Int) throws {
        guard generation == syncGeneration else {
            throw CancellationError()
        }
    }

    private func syncConfirmation(createdCount: Int, deletedCount: Int) -> String {
        switch (createdCount, deletedCount) {
        case (0, 0):
            "Health data is up to date."
        case (_, 0):
            "Synced \(createdCount) new health records."
        case (0, _):
            "Removed \(deletedCount) deleted health records."
        default:
            "Synced \(createdCount) new and removed \(deletedCount) deleted health records."
        }
    }
}
