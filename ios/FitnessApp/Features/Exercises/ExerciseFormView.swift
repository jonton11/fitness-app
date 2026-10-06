import SwiftUI

struct ExerciseFormView: View {
    let exercise: Exercise?
    let onSave: (ExerciseFormState) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var form: ExerciseFormState
    @State private var isSaving = false

    init(
        exercise: Exercise?,
        onSave: @escaping (ExerciseFormState) async -> Bool
    ) {
        self.exercise = exercise
        self.onSave = onSave
        _form = State(initialValue: ExerciseFormState(exercise: exercise))
    }

    var body: some View {
        NavigationStack {
            Form {
                ExerciseFormFields(form: $form)
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task {
                            isSaving = true
                            if await onSave(form) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

struct ExerciseFormFields: View {
    @Binding var form: ExerciseFormState

    var body: some View {
        Section("Exercise") {
            TextField("Name", text: $form.name)
            TextField("Primary muscle group", text: $form.primaryMuscleGroup)
            TextField("Secondary muscle groups", text: $form.secondaryMuscleGroups)

            Picker("Load type", selection: $form.loadType) {
                ForEach(LoadType.allCases) { loadType in
                    Text(loadType.label).tag(loadType)
                }
            }
        }

        Section("Reference") {
            TextField("External URL", text: $form.externalURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)

            TextField("Notes", text: $form.notes, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
        }
    }
}
