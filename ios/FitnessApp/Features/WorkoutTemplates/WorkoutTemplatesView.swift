import SwiftUI

struct WorkoutTemplatesView: View {
    @StateObject private var viewModel = WorkoutTemplatesViewModel()
    @State private var editingTemplate: WorkoutTemplate?
    @State private var isShowingForm = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.templates) { template in
                    Button {
                        editingTemplate = template
                        isShowingForm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("\(template.slots.count) \(template.slots.count == 1 ? "exercise" : "exercises")")
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
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingTemplate = nil
                        isShowingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Workout Template")
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $isShowingForm) {
                WorkoutTemplateFormView(
                    template: editingTemplate,
                    exercises: viewModel.exercises
                ) { form in
                    await viewModel.save(form: form, template: editingTemplate)
                }
            }
        }
    }
}
