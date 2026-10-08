import Foundation

@MainActor
final class RoutineHistoryViewModel: ObservableObject {
    @Published private(set) var sessions: [RoutineSession] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = false
    @Published var errorMessage: String?

    private let listRoutineSessions: (Int) async throws -> RoutineSessionPage
    private var nextOffset = 0

    init(apiClient: RoutineAPIClient = .live) {
        listRoutineSessions = { offset in
            try await apiClient.listRoutineSessions(status: .completed, offset: offset)
        }
    }

    init(listRoutineSessions: @escaping (Int) async throws -> RoutineSessionPage) {
        self.listRoutineSessions = listRoutineSessions
    }

    func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let page = try await listRoutineSessions(0)
            sessions = page.sessions
            applyPagination(page)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load routine history."
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoading, !isLoadingMore else {
            return
        }

        isLoadingMore = true
        defer {
            isLoadingMore = false
        }

        do {
            let page = try await listRoutineSessions(nextOffset)
            let existingIDs = Set(sessions.map(\.id))
            sessions.append(contentsOf: page.sessions.filter { !existingIDs.contains($0.id) })
            applyPagination(page)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load more routine history."
        }
    }

    private func applyPagination(_ page: RoutineSessionPage) {
        nextOffset = page.nextOffset
        canLoadMore = page.hasNextPage
    }
}
