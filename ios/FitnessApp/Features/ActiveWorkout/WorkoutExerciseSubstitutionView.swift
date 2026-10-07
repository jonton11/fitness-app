import SwiftUI

struct WorkoutExerciseSubstitutionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    @State private var searchText = ""
    @State private var isShowingNewExercise = false
    @State private var savingOptionID: UUID?

    var body: some View {
        NavigationStack {
            List {
                if let selectedExercise = viewModel.selectedExercise {
                    Section("Current Exercise") {
                        LabeledContent(
                            selectedExercise.selectedExercise.name,
                            value: selectedExercise.selectedExercise.loadType.label
                        )
                    }
                }

                Section("Existing Substitutes") {
                    if filteredOptions.isEmpty {
                        if searchText.isEmpty {
                            ContentUnavailableView(
                                "No Substitutes",
                                systemImage: "arrow.left.arrow.right"
                            )
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    } else {
                        ForEach(filteredOptions) { option in
                            Button {
                                select(option)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.exercise.name)
                                            .foregroundStyle(.primary)
                                        Text("\(option.exercise.primaryMuscleGroup) · \(option.exercise.loadType.label)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if savingOptionID == option.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .disabled(savingOptionID != nil)
                        }
                    }
                }

                Section {
                    Button {
                        isShowingNewExercise = true
                    } label: {
                        Label("Add New Substitute", systemImage: "plus")
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search substitutes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingNewExercise) {
                NewWorkoutSubstituteView(
                    startingLoadValue: nil,
                    progressionIncrement: nil
                ) { exerciseID, form, startingLoadValue, progressionIncrement in
                    await viewModel.addAndSelectSubstitute(
                        exerciseID: exerciseID,
                        form: form,
                        startingLoadValue: startingLoadValue,
                        progressionIncrement: progressionIncrement
                    )
                }
            }
        }
    }

    private var filteredOptions: [WorkoutTemplateExerciseOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return viewModel.substitutionOptions
        }

        return viewModel.substitutionOptions.filter { option in
            option.exercise.name.localizedCaseInsensitiveContains(query) ||
                option.exercise.primaryMuscleGroup.localizedCaseInsensitiveContains(query)
        }
    }

    private func select(_ option: WorkoutTemplateExerciseOption) {
        savingOptionID = option.id
        Task {
            if await viewModel.substituteSelectedExercise(with: option) {
                dismiss()
            }
            savingOptionID = nil
        }
    }
}

struct NewWorkoutSubstituteView: View {
    let onSave: (UUID, ExerciseFormState, Double?, Double?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var exerciseID = UUID()
    @State private var form = ExerciseFormState()
    @State private var startingLoadValue: String
    @State private var progressionIncrement: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        startingLoadValue: Double?,
        progressionIncrement: Double?,
        onSave: @escaping (UUID, ExerciseFormState, Double?, Double?) async -> Bool
    ) {
        self.onSave = onSave
        _startingLoadValue = State(initialValue: startingLoadValue?.formValue ?? "")
        _progressionIncrement = State(initialValue: progressionIncrement?.formValue ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                ExerciseFormFields(form: $form)

                Section("Progression") {
                    TextField("Starting working load", text: $startingLoadValue)
                        .keyboardType(.decimalPad)
                    TextField("Progression increment", text: $progressionIncrement)
                        .keyboardType(.decimalPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Substitute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        let parsedStartingLoadValue: Double?
        let parsedProgressionIncrement: Double?

        do {
            parsedStartingLoadValue = try optionalNumber(startingLoadValue)
            parsedProgressionIncrement = try optionalNumber(progressionIncrement)
        } catch {
            errorMessage = "Enter valid non-negative progression values."
            return
        }

        isSaving = true
        errorMessage = nil
        Task {
            if await onSave(exerciseID, form, parsedStartingLoadValue, parsedProgressionIncrement) {
                dismiss()
            } else {
                errorMessage = "Could not add exercise."
            }
            isSaving = false
        }
    }

    private func optionalNumber(_ value: String) throws -> Double? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        guard let number = Double(trimmedValue), number >= 0 else {
            throw NewWorkoutSubstituteValidationError.invalidNumber
        }

        return number
    }
}

private enum NewWorkoutSubstituteValidationError: Error {
    case invalidNumber
}

private extension Double {
    var formValue: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}
