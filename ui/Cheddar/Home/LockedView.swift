import SwiftUI

/*
This view's only job is: stand in for a tab a guest can't use, looking like the empty Sessions and Shot Map pages but
with a lock and "Sign up to save your sessions". Signing up is on the Account tab.
*/
struct LockedView: View {
    let title: String

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            NoSessionsYet(message: "Sign up to save your sessions", locked: true)
        }
        .navigationTitle(title)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        LockedView(title: "Shot Map")
    }
}
