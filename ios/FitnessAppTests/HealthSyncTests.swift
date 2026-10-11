import XCTest
@testable import FitnessApp

final class HealthSyncTests: XCTestCase {
    func testHealthMetricAPIClientUploadsRailsBatchEnvelope() async throws {
        let requestBox = HealthRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HealthURLProtocolStub.self]
        let client = HealthMetricAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: URLSession(configuration: configuration),
            bearerToken: "token"
        )
        let metricID = UUID()
        let deletedMetricID = UUID()
        let upload = healthMetricUpload(id: metricID)
        let metric = healthMetric(id: metricID)

        HealthURLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let metrics = try JSONSerialization.jsonObject(with: JSONEncoder().encode([metric]))
            let data = try JSONSerialization.data(withJSONObject: [
                "health_metrics": metrics,
                "meta": ["created": 1, "replayed": 0, "deleted": 1]
            ])
            return (response, data)
        }
        defer {
            HealthURLProtocolStub.requestHandler = nil
        }

        let result = try await client.ingest([upload], deleting: [deletedMetricID])
        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.healthReadData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let metrics = try XCTUnwrap(body["health_metrics"] as? [[String: Any]])
        let deletedMetricIDs = try XCTUnwrap(body["deleted_health_metric_ids"] as? [String])

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/health_metrics")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(metrics.first?["id"] as? String, metricID.uuidString)
        XCTAssertEqual(metrics.first?["kind"] as? String, "body_weight")
        XCTAssertEqual(metrics.first?["unit"] as? String, "kg")
        XCTAssertEqual(deletedMetricIDs, [deletedMetricID.uuidString])
        XCTAssertEqual(result.metrics, [metric])
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(result.replayedCount, 0)
        XCTAssertEqual(result.deletedCount, 1)
    }

    @MainActor
    func testHealthSyncAdvancesAnchorAfterSuccessfulUpload() async throws {
        let recorder = HealthSyncRecorder()
        let defaults = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        let store = HealthSyncStore(defaults: defaults)
        let anchor = Data([1, 2, 3])
        let metric = healthMetricUpload()
        let deletedMetricID = UUID()
        let syncedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let client = HealthKitClient(
            isAvailable: { true },
            requestAuthorization: {
                await recorder.recordAuthorization()
            },
            changes: { kind, _ in
                await recorder.recordQuery(kind)
                return HealthSampleBatch(
                    metrics: kind == .bodyWeight ? [metric] : [],
                    deletedMetricIDs: kind == .bodyWeight ? [deletedMetricID] : [],
                    nextAnchor: kind == .bodyWeight ? anchor : Data(kind.rawValue.utf8),
                    hasMore: false
                )
            }
        )
        let viewModel = HealthSyncViewModel(
            healthKitClient: client,
            healthSyncStore: store,
            ingestMetrics: { metrics, deletedMetricIDs in
                await recorder.recordUpload(metrics, deleting: deletedMetricIDs)
                return HealthMetricIngestionResult(
                    metrics: [],
                    createdCount: metrics.count,
                    replayedCount: 0,
                    deletedCount: deletedMetricIDs.count
                )
            },
            now: { syncedAt }
        )

        await viewModel.setSyncEnabled(true)

        let didRequestAuthorization = await recorder.didRequestAuthorization
        let uploadedMetrics = await recorder.uploadedMetrics
        let uploadedDeletedMetricIDs = await recorder.uploadedDeletedMetricIDs
        let queriedKinds = await recorder.queriedKinds

        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertEqual(viewModel.lastSyncedAt, syncedAt)
        XCTAssertEqual(
            viewModel.confirmationMessage,
            "Synced 1 new and removed 1 deleted health records."
        )
        XCTAssertEqual(store.anchor(for: .bodyWeight), anchor)
        XCTAssertTrue(didRequestAuthorization)
        XCTAssertEqual(uploadedMetrics, [metric])
        XCTAssertEqual(uploadedDeletedMetricIDs, [deletedMetricID])
        XCTAssertEqual(Set(queriedKinds), Set(HealthMetricKind.allCases))
    }

    @MainActor
    func testHealthSyncKeepsAnchorWhenUploadFails() async throws {
        let defaults = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        let store = HealthSyncStore(defaults: defaults)
        let metric = healthMetricUpload()
        let client = HealthKitClient(
            isAvailable: { true },
            requestAuthorization: {},
            changes: { kind, _ in
                HealthSampleBatch(
                    metrics: kind == .bodyWeight ? [metric] : [],
                    deletedMetricIDs: [],
                    nextAnchor: Data([9]),
                    hasMore: false
                )
            }
        )
        let viewModel = HealthSyncViewModel(
            healthKitClient: client,
            healthSyncStore: store,
            ingestMetrics: { _, _ in throw HealthSyncTestError.uploadFailed }
        )

        await viewModel.setSyncEnabled(true)

        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertNil(store.anchor(for: .bodyWeight))
        XCTAssertEqual(viewModel.errorMessage, "Health sync failed. Try again.")
        XCTAssertNil(viewModel.lastSyncedAt)
    }

    @MainActor
    func testChangingCredentialsResetsHealthSyncConsentAndProgress() throws {
        let defaults = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        let store = HealthSyncStore(defaults: defaults)
        let anchor = Data([4, 5, 6])
        let syncedAt = Date(timeIntervalSince1970: 1_800_000_000)
        store.setEnabled(true)
        store.saveAnchor(anchor, for: .bodyWeight)
        store.saveLastSyncedAt(syncedAt)
        let viewModel = HealthSyncViewModel(
            healthKitClient: HealthKitClient(
                isAvailable: { true },
                requestAuthorization: {},
                changes: { _, _ in
                    HealthSampleBatch(
                        metrics: [],
                        deletedMetricIDs: [],
                        nextAnchor: nil,
                        hasMore: false
                    )
                }
            ),
            healthSyncStore: store
        )
        let existingCredentials = APICredentials(
            serverURL: URL(string: "https://fitness.example")!,
            token: "fitness_existing_token"
        )
        let connectionSettings = ConnectionSettingsViewModel(
            loadCredentials: { existingCredentials },
            saveCredentials: { _ in },
            clearCredentials: {}
        )
        connectionSettings.onCredentialsChange = {
            viewModel.resetForCredentialChange()
        }
        connectionSettings.serverURL = "https://fitness-new.example"

        connectionSettings.save()

        XCTAssertTrue(connectionSettings.hasCredentials)
        XCTAssertFalse(viewModel.isEnabled)
        XCTAssertNil(viewModel.lastSyncedAt)
        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.anchor(for: .bodyWeight))
        XCTAssertNil(store.lastSyncedAt)
    }

    @MainActor
    func testChangingCredentialsInvalidatesASuspendedHealthSync() async throws {
        let defaults = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        let store = HealthSyncStore(defaults: defaults)
        let gate = HealthQueryGate()
        let recorder = HealthSyncRecorder()
        let metric = healthMetricUpload()
        let anchor = Data([7, 8, 9])
        let client = HealthKitClient(
            isAvailable: { true },
            requestAuthorization: {},
            changes: { _, _ in
                await gate.nextBatch()
            }
        )
        let viewModel = HealthSyncViewModel(
            healthKitClient: client,
            healthSyncStore: store,
            ingestMetrics: { metrics, deletedMetricIDs in
                await recorder.recordUpload(metrics, deleting: deletedMetricIDs)
                return HealthMetricIngestionResult(
                    metrics: [],
                    createdCount: metrics.count,
                    replayedCount: 0,
                    deletedCount: deletedMetricIDs.count
                )
            }
        )
        let connectionSettings = ConnectionSettingsViewModel(
            loadCredentials: {
                APICredentials(
                    serverURL: URL(string: "https://fitness.example")!,
                    token: "fitness_existing_token"
                )
            },
            saveCredentials: { _ in },
            clearCredentials: {}
        )
        connectionSettings.onCredentialsChange = {
            viewModel.resetForCredentialChange()
        }

        let syncTask = Task {
            await viewModel.setSyncEnabled(true)
        }
        await gate.waitUntilSuspended()
        XCTAssertTrue(viewModel.isSyncing)

        connectionSettings.serverURL = "https://fitness-new.example"
        connectionSettings.save()
        await gate.resume(
            with: HealthSampleBatch(
                metrics: [metric],
                deletedMetricIDs: [],
                nextAnchor: anchor,
                hasMore: false
            )
        )
        await syncTask.value

        let uploadedMetrics = await recorder.uploadedMetrics
        XCTAssertTrue(uploadedMetrics.isEmpty)
        XCTAssertFalse(viewModel.isEnabled)
        XCTAssertFalse(viewModel.isSyncing)
        XCTAssertNil(viewModel.lastSyncedAt)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(store.anchor(for: .bodyWeight))
        XCTAssertNil(store.lastSyncedAt)
    }

    private var defaultsSuiteName: String {
        "HealthSyncTests"
    }

    private func makeDefaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }

    private func healthMetricUpload(id: UUID = UUID()) -> HealthMetricUpload {
        HealthMetricUpload(
            id: id,
            kind: .bodyWeight,
            value: 82.4,
            unit: "kg",
            startedAt: "2026-10-10T08:00:00.000Z",
            endedAt: "2026-10-10T08:00:00.000Z"
        )
    }

    private func healthMetric(id: UUID) -> HealthMetric {
        HealthMetric(
            id: id,
            kind: .bodyWeight,
            value: 82.4,
            unit: "kg",
            startedAt: "2026-10-10T08:00:00.000Z",
            endedAt: "2026-10-10T08:00:00.000Z",
            source: "healthkit",
            createdAt: "2026-10-10T08:01:00.000Z",
            updatedAt: "2026-10-10T08:01:00.000Z"
        )
    }
}

private enum HealthSyncTestError: Error {
    case uploadFailed
}

private actor HealthSyncRecorder {
    private(set) var didRequestAuthorization = false
    private(set) var queriedKinds: [HealthMetricKind] = []
    private(set) var uploadedMetrics: [HealthMetricUpload] = []
    private(set) var uploadedDeletedMetricIDs: [UUID] = []

    func recordAuthorization() {
        didRequestAuthorization = true
    }

    func recordQuery(_ kind: HealthMetricKind) {
        queriedKinds.append(kind)
    }

    func recordUpload(_ metrics: [HealthMetricUpload], deleting deletedMetricIDs: [UUID]) {
        uploadedMetrics.append(contentsOf: metrics)
        uploadedDeletedMetricIDs.append(contentsOf: deletedMetricIDs)
    }
}

private actor HealthQueryGate {
    private var continuation: CheckedContinuation<HealthSampleBatch, Never>?

    func nextBatch() async -> HealthSampleBatch {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilSuspended() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func resume(with batch: HealthSampleBatch) {
        continuation?.resume(returning: batch)
        continuation = nil
    }
}

private final class HealthRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequest: URLRequest?

    var request: URLRequest? {
        get {
            lock.withHealthLock { storedRequest }
        }
        set {
            lock.withHealthLock { storedRequest = newValue }
        }
    }
}

private final class HealthURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withHealthLock<Result>(_ body: () -> Result) -> Result {
        lock()
        defer {
            unlock()
        }
        return body()
    }
}

private extension InputStream {
    func healthReadData() throws -> Data {
        open()
        defer {
            close()
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while hasBytesAvailable {
            let bytesRead = read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                throw streamError ?? URLError(.cannotDecodeRawData)
            } else {
                break
            }
        }
        return data
    }
}
