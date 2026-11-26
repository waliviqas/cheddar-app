import SwiftUI

/*
This screen's only job is: the Account tab. A guest gets only "Sign Up to Save Your Sessions", which opens the Apple and
Google buttons; a guest has no name, since nothing about a guest is kept. A signed-in player gets Name, which changes
what Cheddar calls them, and Delete My Account, which asks first and then deletes the account for good. Everyone gets
Help & Support and Privacy Policy, which open the published support page and policy.
*/
struct SettingsView: View {
    private static let support = URL(string: "https://docs.google.com/document/d/e/2PACX-1vTS_yZmMI-W6_znwcgq-BYkM9RnuT-k0muKr5wiRqhZx2QXmba2yuyf3Nm_Tpi7nTfL8OY0CyKZ91i8/pub")!
    private static let privacyPolicy = URL(string: "https://docs.google.com/document/d/e/2PACX-1vRzMh6ZFsBRFw38WBs9eGx4JQ2JlxwA4y2kK8pQZhhQJtuChhxiFFvmrVeS8-VkkgiwX1brfY_wARHw/pub")!

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
                    supportRow
                    privacyRow
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
                    supportRow
                    privacyRow
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

    // Opens the published support page in Safari: setup tips, why a shot wasn't called, and the contact email.
    private var supportRow: some View {
        Link(destination: Self.support) {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                Text("Help & Support")
                Spacer()
                chevron
            }
            .foregroundStyle(.white)
            .accountRow()
        }
    }

    // Opens the published privacy policy in Safari. Apple wants it reachable from inside the app.
    private var privacyRow: some View {
        Link(destination: Self.privacyPolicy) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised")
                Text("Privacy Policy")
                Spacer()
                chevron
            }
            .foregroundStyle(.white)
            .accountRow()
        }
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
        } catch is AccountDeletion.SignInExpired {
            problem = "Your sign-in expired. Reopen Cheddar, sign in, then delete your account."
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
