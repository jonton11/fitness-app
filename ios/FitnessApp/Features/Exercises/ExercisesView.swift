import SwiftUI

struct ExercisesView: View {
    @StateObject private var viewModel = ExercisesViewModel()
    @State private var editingExercise: Exercise?
    @State private var isShowingForm = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.exercises) { exercise in
                    Button {
                        editingExercise = exercise
                        isShowingForm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("\(exercise.primaryMuscleGroup) · \(exercise.loadType.label)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingExercise = nil
                        isShowingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Exercise")
                }
            }
            .task {
                await viewModel.loadExercises()
            }
            .sheet(isPresented: $isShowingForm) {
                ExerciseFormView(exercise: editingExercise) { form in
                    await viewModel.save(form: form, exercise: editingExercise)
                }
            }
        }
    }
}
