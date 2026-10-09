import Foundation

struct ActivityDraft: Equatable {
    var id: UUID
    var kind: ActivityKind
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var focusTags: String

    init(
        id: UUID = UUID(),
        kind: ActivityKind,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        notes: String = "",
        focusTags: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.focusTags = focusTags
    }
}

@MainActor
final class ActivitiesViewModel: ObservableObject {
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isSaving = false
    @Published private(set) var canLoadMore = false
    @Published var errorMessage: String?

    private let listActivities: (Int) async throws -> ActivityPage
    private let createActivity: (ActivityCreatePayload) async throws -> Activity
    private var nextOffset = 0

    init(apiClient: ActivityAPIClient = .live) {
        listActivities = { offset in
            try await apiClient.listActivities(offset: offset)
        }
        createActivity = { payload in
            try await apiClient.createActivity(payload: payload)
        }
    }

    init(
        listActivities: @escaping (Int) async throws -> ActivityPage,
        createActivity: @escaping (ActivityCreatePayload) async throws -> Activity
    ) {
        self.listActivities = listActivities
        self.createActivity = createActivity
    }

    func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            let page = try await listActivities(0)
            replaceFirstPage(with: page)
        } catch {
            errorMessage = "Could not load activity history."
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else {
            return
        }

        isLoadingMore = true
        errorMessage = nil
        defer {
            isLoadingMore = false
        }

        do {
            let page = try await listActivities(nextOffset)
            let existingIDs = Set(activities.map(\.id))
            activities.append(contentsOf: page.activities.filter { !existingIDs.contains($0.id) })
            nextOffset = page.nextOffset
            canLoadMore = page.hasNextPage
        } catch {
            errorMessage = "Could not load more activity history."
        }
    }

    func log(draft: ActivityDraft) async -> Bool {
        guard !isSaving else {
            return false
        }

        isSaving = true
        errorMessage = nil
        defer {
            isSaving = false
        }

        let payload = ActivityCreatePayload(
            id: draft.id,
            kind: draft.kind,
            startedAt: draft.startedAt.apiTimestamp,
            endedAt: draft.endedAt?.apiTimestamp,
            notes: draft.notes.trimmedOrNil,
            focusTags: draft.focusTags.uniqueCommaSeparatedValues
        )

        do {
            _ = try await createActivity(payload)
        } catch {
            errorMessage = "Could not log activity."
            return false
        }

        do {
            let page = try await listActivities(0)
            replaceFirstPage(with: page)
        } catch {
            nextOffset = 0
            canLoadMore = false
            errorMessage = "Activity logged, but history could not be refreshed."
        }

        return true
    }

    private func replaceFirstPage(with page: ActivityPage) {
        activities = page.activities
        nextOffset = page.nextOffset
        canLoadMore = page.hasNextPage
    }
}

private extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var uniqueCommaSeparatedValues: [String] {
        var seen: Set<String> = []

        return split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
