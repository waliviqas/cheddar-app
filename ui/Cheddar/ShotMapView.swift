import SwiftUI

/*
This screen's only job is: every puck from every session on one net, or one session at a time; tap a dot to watch that shot.
*/
struct ShotMapView: View {
    @Environment(SessionStore.self) private var store
    @State private var picked: Session.ID?
    @State private var replay: Shot?

    private var shots: [Shot] {
        if let picked, let session = store.session(picked) { return session.shots }
        return store.sessions.flatMap(\.shots)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 28) {
                    Picker("Sessions", selection: $picked) {
                        Text("All sessions").tag(Session.ID?.none)
                        ForEach(store.sessions) { session in
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day())).tag(Session.ID?.some(session.id))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                    Spacer()
                    Stat(title: "SHOTS", value: "\(shots.count)")
                    Stat(title: "TOP SPEED", value: shots.compactMap(\.mph).max().mphText, highlight: true)
                }
                MapCard(title: "WHERE EVERY PUCK WENT", hint: "Tap a dot to watch the shot") {
                    NetMapView(shots: shots) { replay = $0 }
                }
                .animation(.easeInOut(duration: 0.3), value: picked)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .navigationTitle("Shot Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .fullScreenCover(item: $replay) { ShotReplayView(shot: $0) }
    }
}
