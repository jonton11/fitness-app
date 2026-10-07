import SwiftUI

struct WorkoutHistoryView: View {
    @StateObject private var viewModel = WorkoutHistoryViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.entries) { entry in
                    NavigationLink {
                        WorkoutHistoryDetailView(entry: entry)
                    } label: {
                        WorkoutHistoryRow(entry: entry)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView()
                } else if !viewModel.isLoading &&
                            viewModel.entries.isEmpty &&
                            viewModel.errorMessage == nil {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed workouts will appear here.")
                    )
                }
            }
            .navigationTitle("History")
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

private struct WorkoutHistoryRow: View {
    let entry: WorkoutHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.session.workoutTemplateName)
                    .font(.headline)

                Spacer()

                if let syncState = entry.syncState {
                    Label(syncState.label, systemImage: syncState.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(syncState == .needsAttention ? .red : .orange)
                }
            }

            Text(entry.session.startedAt.historyDateLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(entry.session.historySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct WorkoutHistoryDetailView: View {
    let entry: WorkoutHistoryEntry

    var body: some View {
        List {
            Section {
                LabeledContent("Started", value: entry.session.startedAt.historyDateLabel)

                if let completedAt = entry.session.completedAt {
                    LabeledContent("Completed", value: completedAt.historyDateLabel)
                }

                if let syncState = entry.syncState {
                    Label(syncState.detailLabel, systemImage: syncState.systemImage)
                        .foregroundStyle(syncState == .needsAttention ? .red : .orange)
                }
            }

            ForEach(entry.session.exercises.sorted { $0.position < $1.position }) { exercise in
                Section {
                    ForEach(exercise.workoutSessionSets.sorted { $0.position < $1.position }) { set in
                        WorkoutHistorySetRow(set: set, loadType: exercise.selectedExercise.loadType)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.label)
                        if exercise.label != exercise.selectedExercise.name {
                            Text(exercise.selectedExercise.name)
                                .textCase(nil)
                        }
                    }
                }
            }
        }
        .navigationTitle(entry.session.workoutTemplateName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WorkoutHistorySetRow: View {
    let set: WorkoutSessionSet
    let loadType: LoadType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: set.completionState.systemImage)
                .foregroundStyle(set.completionState.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Set \(set.position)")
                    .font(.body.weight(.medium))
                Text("Target \(set.targetRepMin)-\(set.targetRepMax) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(resultLabel)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    private var resultLabel: String {
        guard set.completionState.isPerformed,
              let actualReps = set.actualReps else {
            return set.completionState.label
        }

        guard let actualLoadValue = set.actualLoadValue else {
            return "\(actualReps) reps"
        }

        let unit = loadType.historyUnitLabel
        return "\(actualReps) x \(actualLoadValue.formatted())\(unit.isEmpty ? "" : " \(unit)")"
    }
}

private extension WorkoutHistoryEntry.SyncState {
    var label: String {
        switch self {
        case .pending:
            "Pending"
        case .needsAttention:
            "Sync issue"
        }
    }

    var detailLabel: String {
        switch self {
        case .pending:
            "Waiting to sync"
        case .needsAttention:
            "Sync needs attention"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            "arrow.triangle.2.circlepath"
        case .needsAttention:
            "exclamationmark.triangle.fill"
        }
    }
}

private extension WorkoutSessionSetCompletionState {
    var label: String {
        switch self {
        case .pending:
            "Pending"
        case .completed:
            "Completed"
        case .attemptedButTargetNotMet:
            "Target not met"
        case .notPerformed:
            "Not performed"
        }
    }

    var systemImage: String {
        switch self {
        case .completed:
            "checkmark.circle.fill"
        case .attemptedButTargetNotMet:
            "exclamationmark.circle.fill"
        case .notPerformed:
            "minus.circle"
        case .pending:
            "circle"
        }
    }

    var tint: Color {
        switch self {
        case .completed:
            .green
        case .attemptedButTargetNotMet:
            .orange
        case .notPerformed, .pending:
            .secondary
        }
    }
}

private extension LoadType {
    var historyUnitLabel: String {
        switch self {
        case .lb:
            "lb"
        case .kg:
            "kg"
        case .machineStack:
            "stack"
        case .plateCount:
            "plates"
        case .bodyweight:
            "bodyweight"
        case .bodyweightPlusAdded:
            "added"
        case .assisted:
            "assisted"
        case .none:
            ""
        }
    }
}

private extension WorkoutSession {
    var historySummary: String {
        let completedSets = exercises
            .flatMap(\.workoutSessionSets)
            .filter { $0.completionState.isPerformed }
            .count
        let exerciseCount = exercises.count
        let exerciseLabel = exerciseCount == 1 ? "exercise" : "exercises"
        let setLabel = completedSets == 1 ? "set" : "sets"

        return "\(exerciseCount) \(exerciseLabel) - \(completedSets) \(setLabel) logged"
    }
}

private extension String {
    var historyDateLabel: String {
        guard let date = workoutHistoryDate else {
            return "Unknown date"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var workoutHistoryDate: Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: self) {
            return date
        }

        return ISO8601DateFormatter().date(from: self)
    }
}
