import SwiftUI

/// GitHub connection settings. The token is stored in the Keychain.
struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            Form {
                Section("Repository") {
                    labeled("Owner", text: $store.owner, placeholder: "your-username")
                    labeled("Repo", text: $store.repo, placeholder: "training")
                    labeled("File path", text: $store.path, placeholder: "training.md")
                    labeled("Branch", text: $store.branch, placeholder: "main")
                }

                Section("Token") {
                    SecureField("ghp_… (fine-grained PAT)", text: $store.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: store.token) { _ in store.saveToken() }
                    Text("Create a fine-grained token scoped to just this repo with **Contents: Read and write**.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !store.pending.isEmpty {
                    Section("Waiting to sync") {
                        ForEach(store.pending) { write in
                            HStack {
                                Text(Theme.displayName(write.exerciseName))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Session.dateFormatter.string(from: write.date))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("^[\(store.pending.count) change](inflect: true) saved offline. Reloading below pushes them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task { await store.load() }
                    } label: {
                        if store.isBusy { ProgressView() } else { Text("Test connection / reload") }
                    }
                    .disabled(store.isBusy)
                    if !store.status.isEmpty {
                        Text(store.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func labeled(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
        }
    }
}
