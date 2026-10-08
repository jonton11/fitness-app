import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel
    var isRequired = false

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
}
