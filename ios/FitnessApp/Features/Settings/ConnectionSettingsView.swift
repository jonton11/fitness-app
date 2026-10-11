import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel
    @ObservedObject var healthSyncViewModel: HealthSyncViewModel
    let isRequired: Bool

    init(
        viewModel: ConnectionSettingsViewModel,
        isRequired: Bool = false,
        healthSyncViewModel: HealthSyncViewModel = HealthSyncViewModel()
    ) {
        self.viewModel = viewModel
        self.isRequired = isRequired
        self.healthSyncViewModel = healthSyncViewModel
    }

    var body: some View {
        Form {
            Section("Server") {
                TextField("Server URL", text: $viewModel.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Credential") {
                SecureField(viewModel.tokenFieldLabel, text: $viewModel.apiToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if viewModel.hasCredentials && !isRequired {
                healthSection
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let confirmationMessage = viewModel.confirmationMessage {
                Section {
                    Text(confirmationMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    viewModel.save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }

                if viewModel.hasCredentials {
                    Button(role: .destructive) {
                        viewModel.clear()
                    } label: {
                        Label("Clear Credentials", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isRequired ? "Connect" : "Settings")
    }

    private var healthSection: some View {
        Section("Apple Health") {
            Toggle("Health Sync", isOn: healthSyncEnabled)
                .disabled(!healthSyncViewModel.isAvailable || healthSyncViewModel.isSyncing)

            LabeledContent("Status", value: healthSyncViewModel.statusText)

            if let lastSyncedAt = healthSyncViewModel.lastSyncedAt {
                LabeledContent(
                    "Last Sync",
                    value: lastSyncedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }

            if healthSyncViewModel.isEnabled {
                Button {
                    Task {
                        await healthSyncViewModel.syncNow()
                    }
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(healthSyncViewModel.isSyncing)
            }

            if let errorMessage = healthSyncViewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            } else if let confirmationMessage = healthSyncViewModel.confirmationMessage {
                Text(confirmationMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var healthSyncEnabled: Binding<Bool> {
        Binding(
            get: { healthSyncViewModel.isEnabled },
            set: { isEnabled in
                Task {
                    await healthSyncViewModel.setSyncEnabled(isEnabled)
                }
            }
        )
    }
}
