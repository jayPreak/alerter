import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("@")
                            .foregroundStyle(.secondary)
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Instagram Username")
                } footer: {
                    Text("Enter a public Instagram username to track.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addAccount() }
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Checking profile...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .interactiveDismissDisabled(isLoading)
        }
    }

    private func addAccount() async {
        let cleanUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let profile = try await InstagramScraper.shared.fetchProfile(username: cleanUsername)

            let account = TrackedAccount(
                username: cleanUsername,
                followerCount: profile.followers,
                followingCount: profile.following,
                postCount: profile.posts
            )
            account.lastChecked = Date()

            modelContext.insert(account)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
