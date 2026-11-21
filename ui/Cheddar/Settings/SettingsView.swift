import SwiftUI

/*
This screen's only job is: the Account tab. A guest gets only "Sign Up to Save Your Sessions", which opens the Apple and
Google buttons; a guest has no name, since nothing about a guest is kept. A signed-in player gets Name, which changes
what Cheddar calls them, and Delete My Account, which asks first and then deletes the account for good.
*/
struct SettingsView: View {
    var guest = false
    let onSignedIn: () -> Void
    let onAccountDeleted: () -> Void

    @Environment(PlayerName.self) private var player
    @Environment(SessionStore.self) private var store
    @State private var renaming = false
    @State private var newName = ""
    @State private var signingIn = false
    @State private var asking = false
    @State private var deleting = false
    @State private var problem: String?

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                if guest {
                    Button { signingIn = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Sign Up to Save Your Sessions")
                            Spacer()
                            chevron
                        }
                        .foregroundStyle(.white)
                        .accountRow()
                    }
                } else {
                    Button {
                        newName = player.name ?? ""
                        renaming = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person")
                            Text("Name")
                            Spacer()
                            Text(player.name ?? "")
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                            chevron
                        }
                        .foregroundStyle(.white)
                        .accountRow()
                    }
                    Button { asking = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                            Text("Delete My Account")
                            Spacer()
                            if deleting { ProgressView().tint(.white) }
                        }
                        .foregroundStyle(Theme.goalRed)
                        .accountRow()
                    }
                    .disabled(deleting)
                }
                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .navigationTitle("Account")
        .sheet(isPresented: $signingIn) {
            LoginView(showsGuest: false) {
                signingIn = false
                onSignedIn()
            } onGuest: {}
            .presentationDragIndicator(.visible)
        }
        .alert("What should we call you?", isPresented: $renaming) {
            TextField("Your name", text: $newName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Save") { Task { await rename() } }
        }
        .alert("Delete your account?", isPresented: $asking) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await delete() } }
        } message: {
            Text("This permanently deletes your Cheddar account and everything saved to it. It can't be undone.")
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.35))
    }

    private func rename() async {
        problem = nil
        do {
            try await player.save(newName)
        } catch {
            problem = "Couldn't save your name. Check your connection and try again."
        }
    }

    private func delete() async {
        deleting = true
        problem = nil
        do {
            try await AccountDeletion.deleteMyAccount()
            store.forgetEverything()
            onAccountDeleted()
        } catch {
            problem = "Couldn't delete your account. Check your connection and try again."
        }
        deleting = false
    }
}

private extension View {
    func accountRow() -> some View {
        font(.headline)
            .padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08)))
    }
}
