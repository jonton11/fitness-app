import SwiftUI

struct ActiveWorkoutView: View {
    @StateObject private var viewModel: ActiveWorkoutViewModel

    init(session: WorkoutSession, store: ActiveWorkoutStore = .live) {
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(session: session, store: store))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.session.workoutTemplateName)
                        .font(.title2.weight(.bold))

                    Text("\(completedExerciseCount) of \(viewModel.session.exercises.count) exercises complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if viewModel.pendingSyncCount > 0 {
                Section {
                    Label("\(viewModel.pendingSyncCount) set \(viewModel.pendingSyncCount == 1 ? "sync" : "syncs") pending", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                }
            }

            if viewModel.syncIssueCount > 0 {
                Section {
                    Label("\(viewModel.syncIssueCount) set \(viewModel.syncIssueCount == 1 ? "sync issue" : "sync issues")", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Exercises") {
                ForEach(viewModel.session.exercises.sorted { $0.position < $1.position }) { exercise in
                    NavigationLink {
                        ActiveSetLoggingView(viewModel: viewModel, exercise: exercise)
                    } label: {
                        ActiveWorkoutExerciseRow(
                            exercise: exercise,
                            completedSets: viewModel.completedSetCount(for: exercise)
                        )
                    }
                }
            }
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.retryPendingSetUpdates()
        }
    }

    private var completedExerciseCount: Int {
        viewModel.session.exercises.filter { exercise in
            viewModel.completedSetCount(for: exercise) == exercise.workoutSessionSets.count
        }.count
    }
}

private struct ActiveWorkoutExerciseRow: View {
    let exercise: WorkoutSessionExercise
    let completedSets: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: completedSets == exercise.workoutSessionSets.count ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completedSets == exercise.workoutSessionSets.count ? .green : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.label)
                    .font(.headline)

                Text("\(completedSets) of \(exercise.workoutSessionSets.count) sets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ActiveSetLoggingView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let exercise: WorkoutSessionExercise

    var body: some View {
        Form {
            if let currentSet = viewModel.currentSet {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(exercise.label)
                            .font(.title2.weight(.bold))

                        Text("Set \(currentSet.position) of \(exercise.workoutSessionSets.count)")
                            .font(.headline)

                        Text(targetText(for: currentSet))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Reps") {
                    HStack {
                        Button {
                            viewModel.decrementReps()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Decrease reps")

                        TextField("Reps", text: $viewModel.repDraft)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.largeTitle.weight(.bold))

                        Button {
                            viewModel.incrementReps()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase reps")
                    }
                }

                Section("Load") {
                    TextField("Load", text: $viewModel.loadDraft)
                        .keyboardType(.decimalPad)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    Task {
                        _ = await viewModel.saveCurrentSet()
                    }
                } label: {
                    Label("Save Set", systemImage: "checkmark.circle")
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "Exercise Complete",
                        systemImage: "checkmark.circle",
                        description: Text("All planned sets for this exercise have been logged.")
                    )
                }
            }

            if let restEndsAt = viewModel.restEndsAt {
                Section("Rest") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(restText(restEndsAt: restEndsAt, now: context.date))
                            .font(.title3.monospacedDigit())
                    }
                }
            }
        }
        .navigationTitle(exercise.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectExercise(exercise)
        }
    }

    private func targetText(for set: WorkoutSessionSet) -> String {
        let load = set.plannedLoadValue.map { "\($0.formatted()) \(exercise.selectedExercise.loadType.shortLabel)" } ?? "Bodyweight"
        return "Target: \(load) x \(set.targetRepMin)-\(set.targetRepMax)"
    }

    private func restText(restEndsAt: Date, now: Date) -> String {
        let remainingSeconds = max(Int(restEndsAt.timeIntervalSince(now).rounded()), 0)
        return "\(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60))"
    }
}

private extension LoadType {
    var shortLabel: String {
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
