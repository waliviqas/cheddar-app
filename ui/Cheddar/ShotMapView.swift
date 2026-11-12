import SwiftUI

/*
This screen's only job is: where the pucks went. The big net shows every session together, or the one session
picked in the row below it, and the numbers follow the pick. Tap a dot to watch that shot.
*/
struct ShotMapView: View {
    @Environment(SessionStore.self) private var store
    @State private var picked: Session.ID?
    @State private var replay: Shot?

    private var pickedSession: Session? { picked.flatMap { store.session($0) } }
    private var allShots: [Shot] { store.sessions.flatMap(\.shots) }
    private var shots: [Shot] { pickedSession?.shots ?? allShots }
    private var speeds: [Double] { shots.compactMap(\.mph) }
    private var average: Double? { speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 20) {
                        Stat(title: "SHOTS", value: "\(shots.count)")
                        Stat(title: "TOP SPEED", value: speeds.max().mphText, highlight: true)
                        Stat(title: "AVERAGE", value: average.mphText)
                        Spacer()
                    }
                    MapCard(title: pickedSession.map { dayTitle($0.date) } ?? "ALL SESSIONS", hint: "Tap a dot") {
                        NetMapView(shots: shots) { shot in letScreenTurn(); replay = shot }
                    }
                    Text("SESSIONS")
                        .font(.caption.weight(.bold))
                        .kerning(1.5)
                        .foregroundStyle(.white.opacity(0.6))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            SessionMapCard(title: "All", detail: "TOP \(allShots.compactMap(\.mph).max().mphText)",
                                           shots: allShots, picked: picked == nil) { picked = nil }
                            ForEach(store.sessions) { session in
                                SessionMapCard(title: session.date.formatted(.dateTime.month(.abbreviated).day()),
                                               detail: "TOP \(session.topSpeed.mphText)",
                                               shots: session.shots, picked: picked == session.id) { picked = session.id }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Shot Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.3), value: picked)
        .fullScreenCover(item: $replay, onDismiss: keepUpright) { ShotReplayView(shot: $0) }
    }

    private func dayTitle(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()
    }
}

// One choice in the scrolling row: its name, a small net with its pucks, and its top speed. Outlined when picked.
private struct SessionMapCard: View {
    let title: String
    let detail: String
    let shots: [Shot]
    let picked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                NetMapView(shots: shots)
                    .frame(width: 130)
                Text(detail)
                    .font(.caption.weight(.bold))
                    .kerning(1)
                    .foregroundStyle(Theme.cheddar)
            }
            .padding(12)
            .background(.white.opacity(picked ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(picked ? Theme.cheddar : .white.opacity(0.08), lineWidth: picked ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}
