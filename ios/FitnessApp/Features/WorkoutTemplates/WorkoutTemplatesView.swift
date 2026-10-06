import SwiftUI

struct WorkoutTemplatesView: View {
    @StateObject private var viewModel = WorkoutTemplatesViewModel()
    @State private var editingTemplate: WorkoutTemplate?
    @State private var isShowingForm = false
    @State private var activeWorkoutSession: WorkoutSession?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if let activeSession = viewModel.activeSession {
                    Section("Active Workout") {
                        Button {
                            activeWorkoutSession = activeSession
                        } label: {
                            Label(activeSession.workoutTemplateName, systemImage: "figure.strengthtraining.traditional")
                        }
                    }
                }

                ForEach(viewModel.templates) { template in
                    HStack(spacing: 12) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                activeWorkoutSession = await viewModel.startWorkout(template: template)
                            }
                        } label: {
                            if viewModel.startingTemplateID == template.id {
                                ProgressView()
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .disabled(viewModel.startingTemplateID != nil)
                        .accessibilityLabel("Start \(template.name)")
                        .buttonStyle(.borderless)
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
            .sheet(item: $activeWorkoutSession) { session in
                NavigationStack {
                    ActiveWorkoutView(
                        session: session,
                        workoutTemplate: viewModel.templates.first { $0.id == session.workoutTemplateID }
                    )
                }
                    .onDisappear {
                        viewModel.refreshActiveSession()
                    }
            }
        }
    }
}
