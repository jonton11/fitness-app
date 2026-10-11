import Foundation
import HealthKit

struct HealthSampleBatch: Equatable, Sendable {
    var metrics: [HealthMetricUpload]
    var deletedMetricIDs: [UUID]
    var nextAnchor: Data?
    var hasMore: Bool
}

struct HealthKitClient: Sendable {
    var isAvailable: @Sendable () -> Bool
    var requestAuthorization: @Sendable () async throws -> Void
    var changes: @Sendable (HealthMetricKind, Data?) async throws -> HealthSampleBatch

    static let live: HealthKitClient = {
        let reader = HealthKitReader()
        return HealthKitClient(
            isAvailable: { HKHealthStore.isHealthDataAvailable() },
            requestAuthorization: { try await reader.requestAuthorization() },
            changes: { kind, anchor in
                try await reader.changes(for: kind, anchorData: anchor)
            }
        )
    }()
}

private final class HealthKitReader: @unchecked Sendable {
    private static let batchLimit = 500

    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        let readTypes = Set(HealthMetricKind.allCases.map(sampleType))
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func changes(for kind: HealthMetricKind, anchorData: Data?) async throws -> HealthSampleBatch {
        let anchor = try anchorData.flatMap {
            try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType(for: kind),
                predicate: nil,
                anchor: anchor,
                limit: Self.batchLimit
            ) { [weak self] _, samples, deletedObjects, nextAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                do {
                    let samples = samples ?? []
                    let deletedMetricIDs = (deletedObjects ?? []).map(\.uuid)
                    let metrics = try samples.compactMap { sample in
                        try self?.normalizedMetric(from: sample, kind: kind)
                    }
                    let nextAnchorData = try nextAnchor.map {
                        try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
                    }
                    continuation.resume(
                        returning: HealthSampleBatch(
                            metrics: metrics,
                            deletedMetricIDs: deletedMetricIDs,
                            nextAnchor: nextAnchorData,
                            hasMore: samples.count + deletedMetricIDs.count == Self.batchLimit
                                && nextAnchorData != nil
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            healthStore.execute(query)
        }
    }

    private func sampleType(for kind: HealthMetricKind) -> HKSampleType {
        switch kind {
        case .bodyWeight:
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        case .bodyFatPercentage:
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
        case .steps:
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        case .activeEnergy:
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        case .sleepDuration:
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        case .restingHeartRate:
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        }
    }

    private func normalizedMetric(from sample: HKSample, kind: HealthMetricKind) throws -> HealthMetricUpload? {
        let value: Double

        if kind == .sleepDuration {
            guard let categorySample = sample as? HKCategorySample,
                  let sleepValue = HKCategoryValueSleepAnalysis(rawValue: categorySample.value),
                  Self.asleepValues.contains(sleepValue) else {
                return nil
            }
            value = sample.endDate.timeIntervalSince(sample.startDate) / 60
        } else {
            guard let quantitySample = sample as? HKQuantitySample else {
                return nil
            }
            value = normalizedValue(from: quantitySample, kind: kind)
        }

        return HealthMetricUpload(
            id: sample.uuid,
            kind: kind,
            value: value,
            unit: kind.unit,
            startedAt: Self.serialize(sample.startDate),
            endedAt: Self.serialize(sample.endDate)
        )
    }

    private func normalizedValue(from sample: HKQuantitySample, kind: HealthMetricKind) -> Double {
        switch kind {
        case .bodyWeight:
            sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        case .bodyFatPercentage:
            sample.quantity.doubleValue(for: .percent()) * 100
        case .steps:
            sample.quantity.doubleValue(for: .count())
        case .activeEnergy:
            sample.quantity.doubleValue(for: .kilocalorie())
        case .restingHeartRate:
            sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        case .sleepDuration:
            0
        }
    }

    private static let asleepValues: Set<HKCategoryValueSleepAnalysis> = [
        .asleepUnspecified,
        .asleepCore,
        .asleepDeep,
        .asleepREM
    ]

    private static func serialize(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
