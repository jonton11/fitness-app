import Foundation

struct HealthMetricAPIClient: Sendable {
    private let configuration: APIConfiguration
    private let session: URLSession

    static let live = HealthMetricAPIClient(
        configuration: .live,
        session: .shared
    )

    init(baseURL: URL, session: URLSession, bearerToken: String? = nil) {
        configuration = APIConfiguration(baseURL: baseURL, bearerToken: bearerToken)
        self.session = session
    }

    init(configuration: APIConfiguration, session: URLSession) {
        self.configuration = configuration
        self.session = session
    }

    func ingest(
        _ metrics: [HealthMetricUpload],
        deleting deletedMetricIDs: [UUID] = []
    ) async throws -> HealthMetricIngestionResult {
        var request = try configuration.makeRequest(path: "/api/v1/health_metrics")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            HealthMetricRequestEnvelope(
                healthMetrics: metrics,
                deletedHealthMetricIDs: deletedMetricIDs
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HealthMetricAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HealthMetricAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let envelope = try JSONDecoder().decode(HealthMetricResponseEnvelope.self, from: data)
        return HealthMetricIngestionResult(
            metrics: envelope.healthMetrics,
            createdCount: envelope.meta.created,
            replayedCount: envelope.meta.replayed,
            deletedCount: envelope.meta.deleted
        )
    }
}

enum HealthMetricAPIError: Error, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
}

private struct HealthMetricRequestEnvelope: Encodable {
    var healthMetrics: [HealthMetricUpload]
    var deletedHealthMetricIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case healthMetrics = "health_metrics"
        case deletedHealthMetricIDs = "deleted_health_metric_ids"
    }
}

private struct HealthMetricResponseEnvelope: Decodable {
    var healthMetrics: [HealthMetric]
    var meta: HealthMetricIngestionMeta

    enum CodingKeys: String, CodingKey {
        case healthMetrics = "health_metrics"
        case meta
    }
}

private struct HealthMetricIngestionMeta: Decodable {
    var created: Int
    var replayed: Int
    var deleted: Int
}
