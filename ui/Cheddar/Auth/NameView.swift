import SwiftUI

/*
This screen's only job is: ask a newly signed-in player what Cheddar should call them, and save it to their account.
It shows after the first sign-in with Apple or Google, whenever the account has no name yet.
*/
struct NameView: View {
    @Environment(PlayerName.self) private var player
    @State private var text = ""
    @State private var saving = false
    @State private var problem: String?
    @FocusState private var typing: Bool

    private var ready: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !saving }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Text("What should we call you?")
                    .font(Theme.display(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                TextField("", text: $text, prompt: Text("Your name").foregroundStyle(.white.opacity(0.35)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($typing)
                    .onSubmit { if ready { Task { await save() } } }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12)))
                    .padding(.top, 28)
                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                Spacer()
                Button { Task { await save() } } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(Theme.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.cheddar, in: Capsule())
                }
                .disabled(!ready)
                .opacity(ready ? 1 : 0.5)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
        .onAppear { typing = true }
    }

    private func save() async {
        saving = true
        problem = nil
        do {
            try await player.save(text)
        } catch {
            problem = "Couldn't save your name. Check your connection and try again."
        }
        saving = false
    }
}

#Preview {
    NameView()
        .environment(PlayerName())
}
