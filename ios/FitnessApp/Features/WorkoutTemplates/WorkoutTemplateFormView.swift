import SwiftUI

struct WorkoutTemplateFormView: View {
    let template: WorkoutTemplate?
    let exercises: [Exercise]
    let onSave: (WorkoutTemplateFormState) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var form: WorkoutTemplateFormState
    @State private var isSaving = false

    init(
        template: WorkoutTemplate?,
        exercises: [Exercise],
        onSave: @escaping (WorkoutTemplateFormState) async -> Bool
    ) {
        self.template = template
        self.exercises = exercises
        self.onSave = onSave
        _form = State(initialValue: WorkoutTemplateFormState(template: template))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name", text: $form.name)

                    TextField("Notes", text: $form.notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }

                Section("Slots") {
                    ForEach(form.slots.indices, id: \.self) { index in
                        slotFields(index: index)
                    }

                    Button("Add Slot") {
                        form.slots.append(
                            WorkoutTemplateSlotFormState(defaultExerciseID: exercises.first?.id)
                        )
                    }
                    .disabled(exercises.isEmpty)
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
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

    @ViewBuilder
    private func slotFields(index: Int) -> some View {
        let slotNumber = index + 1

        Section("Slot \(slotNumber)") {
            TextField("Label", text: $form.slots[index].label)

            Picker("Default exercise", selection: $form.slots[index].defaultExerciseID) {
                Text("Select exercise").tag(Optional<UUID>.none)

                ForEach(exercises) { exercise in
                    Text(exercise.name).tag(Optional(exercise.id))
                }
            }

            TextField("Rest seconds", text: $form.slots[index].restSeconds)
                .keyboardType(.numberPad)

            TextField("Starting load", text: $form.slots[index].startingLoadValue)
                .keyboardType(.decimalPad)

            TextField("Next load", text: $form.slots[index].nextLoadValue)
                .keyboardType(.decimalPad)

            TextField("Progression increment", text: $form.slots[index].progressionIncrement)
                .keyboardType(.decimalPad)

            Picker("Set type", selection: $form.slots[index].setType) {
                ForEach(SetType.allCases) { setType in
                    Text(setType.label).tag(setType)
                }
            }

            TextField("Rep min", text: $form.slots[index].repMin)
                .keyboardType(.numberPad)

            TextField("Rep max", text: $form.slots[index].repMax)
                .keyboardType(.numberPad)

            Picker("Load strategy", selection: $form.slots[index].loadStrategy) {
                ForEach(LoadStrategy.allCases) { loadStrategy in
                    Text(loadStrategy.label).tag(loadStrategy)
                }
            }

            TextField("Load value", text: $form.slots[index].loadValue)
                .keyboardType(.decimalPad)

            Button("Remove Slot", role: .destructive) {
                form.slots.remove(at: index)
            }
        }
    }
}
