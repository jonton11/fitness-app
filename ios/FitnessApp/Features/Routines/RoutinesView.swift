import SwiftUI

struct RoutinesView: View {
    @StateObject private var viewModel: RoutinesViewModel
    @State private var presentedSession: RoutineSession?

    init(viewModel: RoutinesViewModel = RoutinesViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            if !viewModel.activeSessions.isEmpty {
                Section("In Progress") {
                    ForEach(viewModel.activeSessions) { session in
                        Button {
                            presentedSession = session
                        } label: {
                            RoutineSessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Available") {
                ForEach(viewModel.routines) { routine in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.name)
                                .font(.headline)

                            Text(routine.itemCountLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let notes = routine.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            Task {
                                presentedSession = await viewModel.start(routine: routine)
                            }
                        } label: {
                            if viewModel.startingRoutineID == routine.id {
                                ProgressView()
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .disabled(viewModel.startingRoutineID != nil)
                        .accessibilityLabel("Start \(routine.name)")
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.routines.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading &&
                        viewModel.routines.isEmpty &&
                        viewModel.activeSessions.isEmpty &&
                        viewModel.errorMessage == nil {
                ContentUnavailableView(
                    "No Routines Yet",
                    systemImage: "checklist",
                    description: Text("Create a routine from the web app to get started.")
                )
            }
        }
        .navigationTitle("Routines")
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $presentedSession) { session in
            NavigationStack {
                ActiveRoutineView(
                    viewModel: viewModel,
                    sessionID: session.id
                )
            }
        }
    }
}

private struct RoutineSessionRow: View {
    let session: RoutineSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.routineName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(session.completedItemCount) of \(session.items.count) complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct ActiveRoutineView: View {
    @ObservedObject var viewModel: RoutinesViewModel
    let sessionID: UUID

    @Environment(\.dismiss) private var dismiss

    private var session: RoutineSession? {
        viewModel.activeSessions.first { $0.id == sessionID }
    }

    var body: some View {
        Group {
            if let session {
                List {
                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }

                    Section {
                        ProgressView(
                            value: Double(session.completedItemCount),
                            total: Double(max(session.items.count, 1))
                        )
                        Text("\(session.completedItemCount) of \(session.items.count) complete")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        ForEach(session.items.sorted { $0.position < $1.position }) { item in
                            Button {
                                Task {
                                    await viewModel.toggle(itemID: item.id, in: session.id)
                                }
                            } label: {
                                RoutineChecklistRow(
                                    item: item,
                                    isUpdating: viewModel.updatingItemIDs.contains(item.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.updatingItemIDs.contains(item.id))
                            .accessibilityLabel(
                                "\(item.isCompleted ? "Mark incomplete" : "Mark complete") \(item.exerciseName)"
                            )
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        Task {
                            if await viewModel.complete(sessionID: session.id) {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.completingSessionID == session.id {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Finish Routine")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!session.items.allSatisfy(\.isCompleted) || viewModel.completingSessionID != nil)
                    .padding()
                    .background(.bar)
                }
                .navigationTitle(session.routineName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Routine Unavailable",
                    systemImage: "checklist",
                    description: Text("This routine is no longer active.")
                )
            }
        }
    }
}

private struct RoutineChecklistRow: View {
    let item: RoutineSessionItem
    let isUpdating: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUpdating {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.exerciseName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .strikethrough(item.isCompleted)

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
        .contentShape(Rectangle())
    }
}

extension RoutineSessionItem {
    var targetSummary: String {
        switch targetMode {
        case .completionOnly:
            "Complete once"
        case .reps:
            countTarget(unit: "reps", value: targetReps)
        case .duration:
            countTarget(unit: "sec", value: targetDurationSeconds)
        case .loadOptional:
            "\(countTarget(unit: "reps", value: targetReps)) - load optional"
        }
    }

    private func countTarget(unit: String, value: Int?) -> String {
        let target = value.map { "\($0) \(unit)" } ?? unit.capitalized
        guard let sets else {
            return target
        }

        return "\(sets) x \(target)"
    }
}

private extension Routine {
    var itemCountLabel: String {
        "\(items.count) \(items.count == 1 ? "item" : "items")"
    }
}

private extension RoutineSession {
    var completedItemCount: Int {
        items.filter(\.isCompleted).count
    }
}
