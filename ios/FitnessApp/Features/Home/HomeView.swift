import SwiftUI

struct HomeView: View {
    @StateObject private var activityViewModel: ActivitiesViewModel
    @StateObject private var workoutViewModel: WorkoutTemplatesViewModel
    @StateObject private var suggestionViewModel: WorkoutSuggestionViewModel
    @State private var presentedKind: ActivityKind?
    @State private var activeWorkoutSession: WorkoutSession?

    init(
        activityViewModel: ActivitiesViewModel = ActivitiesViewModel(),
        workoutViewModel: WorkoutTemplatesViewModel = WorkoutTemplatesViewModel(),
        suggestionViewModel: WorkoutSuggestionViewModel = WorkoutSuggestionViewModel()
    ) {
        _activityViewModel = StateObject(wrappedValue: activityViewModel)
        _workoutViewModel = StateObject(wrappedValue: workoutViewModel)
        _suggestionViewModel = StateObject(wrappedValue: suggestionViewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                errorRows
                activeWorkoutSection
                suggestedWorkoutSection
                quickLogSection
                recentActivitySection
            }
            .overlay {
                if activityViewModel.isLoading && activityViewModel.activities.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle("Home")
            .refreshable {
                await refresh()
            }
            .task {
                await activityViewModel.load()
            }
            .task {
                await workoutViewModel.load()
            }
            .task {
                await suggestionViewModel.load()
            }
            .sheet(item: $presentedKind) { kind in
                NavigationStack {
                    ActivityFormView(kind: kind, viewModel: activityViewModel) {
                        await suggestionViewModel.load()
                    }
                }
            }
            .sheet(item: $activeWorkoutSession) { session in
                NavigationStack {
                    ActiveWorkoutView(
                        session: session,
                        workoutTemplate: workoutViewModel.activeWorkoutTemplate
                    )
                }
                .onDisappear {
                    workoutViewModel.refreshActiveSession()
                    Task {
                        await suggestionViewModel.load()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorRows: some View {
        if let errorMessage = activityViewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }

        if let errorMessage = workoutViewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var activeWorkoutSection: some View {
        if let activeSession = workoutViewModel.activeSession {
            Section("Active Workout") {
                Button {
                    activeWorkoutSession = activeSession
                } label: {
                    Label(activeSession.workoutTemplateName, systemImage: "play.circle.fill")
                }
            }
        }
    }

    private var suggestedWorkoutSection: some View {
        Section("Suggested") {
            if suggestionViewModel.isLoading && suggestionViewModel.suggestion == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let suggestion = suggestionViewModel.suggestion {
                VStack(alignment: .leading, spacing: 10) {
                    Text(suggestion.workoutTemplateName)
                        .font(.headline)

                    if !suggestion.focusTags.isEmpty {
                        Text(suggestion.focusTags.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(suggestion.recencyLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        startSuggestedWorkout(suggestion)
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        suggestedTemplate(for: suggestion) == nil ||
                            workoutViewModel.activeSession != nil ||
                            workoutViewModel.startingTemplateID != nil
                    )
                }
                .padding(.vertical, 4)
            } else if let errorMessage = suggestionViewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            } else {
                Text("No suggested workout yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickLogSection: some View {
        Section("Quick Log") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(ActivityKind.allCases) { kind in
                    Button {
                        presentedKind = kind
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(kind.tint)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var recentActivitySection: some View {
        Section("Recent Activity") {
            if !activityViewModel.isLoading && activityViewModel.activities.isEmpty {
                Text("No activities logged yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(activityViewModel.activities) { activity in
                ActivityRow(activity: activity)
            }

            if activityViewModel.canLoadMore {
                Button {
                    Task {
                        await activityViewModel.loadMore()
                    }
                } label: {
                    if activityViewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Load More")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(activityViewModel.isLoadingMore)
            }
        }
    }

    private func refresh() async {
        await activityViewModel.load()
        await workoutViewModel.load()
        await suggestionViewModel.load()
    }

    private func suggestedTemplate(for suggestion: WorkoutSuggestion) -> WorkoutTemplate? {
        workoutViewModel.templates.first { $0.id == suggestion.workoutTemplateID }
    }

    private func startSuggestedWorkout(_ suggestion: WorkoutSuggestion) {
        guard let template = suggestedTemplate(for: suggestion) else {
            return
        }

        Task {
            activeWorkoutSession = await workoutViewModel.startWorkout(template: template)
        }
    }
}

private struct ActivityFormView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    let onSaved: () async -> Void
    @State private var draft: ActivityDraft
    @State private var validationMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(
        kind: ActivityKind,
        viewModel: ActivitiesViewModel,
        onSaved: @escaping () async -> Void
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        _draft = State(initialValue: ActivityDraft(kind: kind))
    }

    var body: some View {
        Form {
            if let message = validationMessage ?? viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Section("Activity") {
                Picker("Type", selection: $draft.kind) {
                    ForEach(ActivityKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.systemImage)
                            .tag(kind)
                    }
                }

                DatePicker(
                    "Started",
                    selection: $draft.startedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Toggle("Include end time", isOn: includesEndTime)

                if draft.endedAt != nil {
                    DatePicker(
                        "Ended",
                        selection: endedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            Section("Details") {
                TextField("Focus tags, separated by commas", text: $draft.focusTags)

                TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    .lineLimit(4...8)
            }
        }
        .navigationTitle("Log Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(viewModel.isSaving)
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private var includesEndTime: Binding<Bool> {
        Binding(
            get: { draft.endedAt != nil },
            set: { isIncluded in
                validationMessage = nil
                draft.endedAt = isIncluded ? draft.startedAt : nil
            }
        )
    }

    private var endedAt: Binding<Date> {
        Binding(
            get: { draft.endedAt ?? draft.startedAt },
            set: { draft.endedAt = $0 }
        )
    }

    private func save() {
        validationMessage = nil

        if let endedAt = draft.endedAt, endedAt < draft.startedAt {
            validationMessage = "End time must be at or after the start time."
            return
        }

        Task {
            if await viewModel.log(draft: draft) {
                await onSaved()
                dismiss()
            }
        }
    }
}

private struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activity.kind.systemImage)
                .font(.title3)
                .foregroundStyle(activity.kind.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activity.kind.title)
                        .font(.headline)

                    Spacer()

                    Text(activity.startedAt.activityDateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let duration = activity.durationLabel {
                    Text(duration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let notes = activity.notes {
                    Text(notes)
                        .font(.subheadline)
                }

                if !activity.focusTags.isEmpty {
                    Text(activity.focusTags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension ActivityKind {
    var title: String {
        switch self {
        case .restDay:
            "Rest Day"
        case .basketball:
            "Basketball"
        case .recovery:
            "Recovery"
        case .other:
            "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .restDay:
            "moon.zzz.fill"
        case .basketball:
            "basketball.fill"
        case .recovery:
            "heart.fill"
        case .other:
            "figure.mixed.cardio"
        }
    }

    var tint: Color {
        switch self {
        case .restDay:
            .indigo
        case .basketball:
            .orange
        case .recovery:
            .green
        case .other:
            .blue
        }
    }
}

private extension Activity {
    var durationLabel: String? {
        guard let start = startedAt.activityDate,
              let endedAt,
              let end = endedAt.activityDate else {
            return nil
        }

        let minutes = max(0, Int((end.timeIntervalSince(start) / 60).rounded()))
        return "\(minutes) min"
    }
}

private extension WorkoutSuggestion {
    var recencyLabel: String {
        guard let lastRelevantAt,
              let date = lastRelevantAt.activityDate else {
            return "No recent matching activity"
        }

        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.unitsStyle = .full
        let relativeDate = relativeDateFormatter.localizedString(for: date, relativeTo: Date())
        return "Last relevant activity \(relativeDate)"
    }
}

private extension String {
    var activityDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: self) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }

    var activityDateLabel: String {
        guard let date = activityDate else {
            return self
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
