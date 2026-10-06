import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @State private var isConfirmingCancel = false
    @State private var isConfirmingSkip = false
    @State private var isShowingExerciseSwap = false
    @State private var isShowingNewExercise = false

    init(
        session: WorkoutSession,
        workoutTemplate: WorkoutTemplate? = nil,
        store: ActiveWorkoutStore = .live
    ) {
        _viewModel = StateObject(
            wrappedValue: ActiveWorkoutViewModel(
                session: session,
                workoutTemplate: workoutTemplate,
                store: store
            )
        )
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
                    Label("\(viewModel.pendingSyncCount) \(viewModel.pendingSyncCount == 1 ? "sync" : "syncs") pending", systemImage: "arrow.triangle.2.circlepath")
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task {
                            _ = await viewModel.finishWorkout()
                        }
                    } label: {
                        Label("Finish Workout", systemImage: "checkmark.circle")
                    }
                    .disabled(viewModel.session.status != .active)

                    Button {
                        isConfirmingSkip = true
                    } label: {
                        Label("Skip Exercise", systemImage: "forward.end")
                    }
                    .disabled(viewModel.session.status != .active || viewModel.currentSet == nil)

                    Button {
                        isShowingExerciseSwap = true
                    } label: {
                        Label("Swap Exercise", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(!viewModel.canModifySelectedExercise || viewModel.substitutionOptions.isEmpty)

                    Button {
                        isShowingNewExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                    }
                    .disabled(!viewModel.canModifySelectedExercise)

                    Button(role: .destructive) {
                        isConfirmingCancel = true
                    } label: {
                        Label("Cancel Workout", systemImage: "xmark.circle")
                    }
                    .disabled(viewModel.session.status != .active)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Workout Actions")
            }
        }
        .task {
            await viewModel.retryPendingSync()
        }
        .sheet(isPresented: $isShowingExerciseSwap) {
            WorkoutExerciseSubstitutionView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingNewExercise) {
            NewWorkoutSubstituteView(
                startingLoadValue: nil,
                progressionIncrement: nil
            ) { form, startingLoadValue, progressionIncrement in
                await viewModel.addAndSelectSubstitute(
                    form: form,
                    startingLoadValue: startingLoadValue,
                    progressionIncrement: progressionIncrement
                )
            }
        }
        .confirmationDialog(
            skipConfirmationTitle,
            isPresented: $isConfirmingSkip,
            titleVisibility: .visible
        ) {
            Button("Skip Exercise", role: .destructive) {
                Task {
                    _ = await viewModel.skipSelectedExercise()
                }
            }
        } message: {
            Text("Completed sets are preserved. Remaining sets will be marked not performed.")
        }
        .confirmationDialog(
            "Cancel this workout?",
            isPresented: $isConfirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Cancel Workout", role: .destructive) {
                Task {
                    let didCancel = await viewModel.cancelWorkout()
                    if didCancel && viewModel.pendingSyncCount == 0 {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Logged sets are preserved, but this workout will not affect progression.")
        }
    }

    private var completedExerciseCount: Int {
        viewModel.session.exercises.filter { exercise in
            viewModel.completedSetCount(for: exercise) == exercise.workoutSessionSets.count
        }.count
    }

    private var skipConfirmationTitle: String {
        guard let selectedExercise = viewModel.selectedExercise else {
            return "Skip this exercise?"
        }

        return "Skip \(selectedExercise.selectedExercise.name)?"
    }
}

private struct ActiveWorkoutExerciseRow: View {
    let exercise: WorkoutSessionExercise
    let completedSets: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.selectedExercise.name)
                    .font(.headline)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if exercise.status == .skipped {
            return "forward.end.circle.fill"
        }

        return completedSets == exercise.workoutSessionSets.count ? "checkmark.circle.fill" : "circle"
    }

    private var statusColor: Color {
        exercise.status == .skipped || completedSets < exercise.workoutSessionSets.count ? .secondary : .green
    }

    private var statusText: String {
        if exercise.status == .skipped {
            return "Skipped"
        }

        let performedSets = exercise.workoutSessionSets.count { $0.completionState.isPerformed }
        if completedSets == exercise.workoutSessionSets.count,
           performedSets < exercise.workoutSessionSets.count {
            return "\(performedSets) sets logged; rest skipped"
        }

        return "\(performedSets) of \(exercise.workoutSessionSets.count) sets logged"
    }
}

private struct ActiveSetLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let exercise: WorkoutSessionExercise
    @State private var isConfirmingSkip = false
    @State private var isShowingExerciseSwap = false

    var body: some View {
        Form {
            if let currentSet = viewModel.currentSet {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(activeExercise.selectedExercise.name)
                            .font(.title2.weight(.bold))

                        Text("Set \(currentSet.position) of \(activeExercise.workoutSessionSets.count)")
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

                Section {
                    Button {
                        isShowingExerciseSwap = true
                    } label: {
                        Label("Swap Exercise", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(!viewModel.canModifySelectedExercise || viewModel.substitutionOptions.isEmpty)

                    Button {
                        isConfirmingSkip = true
                    } label: {
                        Label("Skip Exercise", systemImage: "forward.end")
                    }
                    .disabled(viewModel.currentSet == nil)
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
        .navigationTitle(activeExercise.selectedExercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectExercise(exercise)
        }
        .sheet(isPresented: $isShowingExerciseSwap) {
            WorkoutExerciseSubstitutionView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Skip \(activeExercise.selectedExercise.name)?",
            isPresented: $isConfirmingSkip,
            titleVisibility: .visible
        ) {
            Button("Skip Exercise", role: .destructive) {
                Task {
                    if await viewModel.skipSelectedExercise() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Completed sets are preserved. Remaining sets will be marked not performed.")
        }
    }

    private func targetText(for set: WorkoutSessionSet) -> String {
        let load = set.plannedLoadValue.map { "\($0.formatted()) \(activeExercise.selectedExercise.loadType.shortLabel)" } ?? "Bodyweight"
        return "Target: \(load) x \(set.targetRepMin)-\(set.targetRepMax)"
    }

    private var activeExercise: WorkoutSessionExercise {
        viewModel.session.exercises.first { $0.id == exercise.id } ?? exercise
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
