import SwiftUI

struct RoutineHistoryView: View {
    @StateObject private var viewModel: RoutineHistoryViewModel

    init(viewModel: RoutineHistoryViewModel = RoutineHistoryViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            ForEach(viewModel.sessions) { session in
                NavigationLink {
                    RoutineHistoryDetailView(session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.routineName)
                            .font(.headline)

                        Text(session.startedAt.routineHistoryDateLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(session.items.count) \(session.items.count == 1 ? "item" : "items") completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if viewModel.canLoadMore {
                Button {
                    Task {
                        await viewModel.loadMore()
                    }
                } label: {
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Load More")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoadingMore)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading &&
                        viewModel.sessions.isEmpty &&
                        viewModel.errorMessage == nil {
                ContentUnavailableView(
                    "No Routine History",
                    systemImage: "checklist.checked",
                    description: Text("Completed routines will appear here.")
                )
            }
        }
        .navigationTitle("Routine History")
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct RoutineHistoryDetailView: View {
    let session: RoutineSession

    var body: some View {
        List {
            Section {
                LabeledContent("Started", value: session.startedAt.routineHistoryDateLabel)

                if let completedAt = session.completedAt {
                    LabeledContent("Completed", value: completedAt.routineHistoryDateLabel)
                }
            }

            Section("Checklist") {
                ForEach(session.items.sorted { $0.position < $1.position }) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.exerciseName)
                                .font(.body.weight(.medium))
                            Text(item.targetSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let notes = item.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(session.routineName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension String {
    var routineHistoryDateLabel: String {
        guard let date = routineHistoryDate else {
            return "Unknown date"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var routineHistoryDate: Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: self) {
            return date
        }

        return ISO8601DateFormatter().date(from: self)
    }
}
