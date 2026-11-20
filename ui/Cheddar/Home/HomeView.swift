import SwiftUI

/*
This screen's only job is: the home page and its tab bar, so the player can switch between Home, Shot Map, Sessions
and Account. A guest gets only the speed reader: Shot Map and Sessions show a lock and "Sign up to save your sessions". Start
Session on the Home tab opens the turn-your-phone screen, which opens the camera, sideways. Closing the camera comes
back here; a signed-in player's finished recording is logged as a session and opens on the Sessions tab. The top of
Home greets the player by name.
*/
enum Route: Hashable {
    case session(Session.ID)
}

struct HomeView: View {
    var guest = false                 // only the speed reader, and nothing is kept
    var onSignedIn: () -> Void = {}   // a guest signed up from the Account tab
    var onSignedOut: () -> Void = {}

    @Environment(PlayerName.self) private var player
    @State private var store = SessionStore()
    @State private var sessionsPath: [Route] = []
    @State private var turning = false
    @State private var filming = false
    @State private var tab = Tab.home

    private enum Tab { case home, shotMap, sessions, account }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                ZStack(alignment: .top) {
                    Theme.background.ignoresSafeArea()
                    Button { turning = true } label: {
                        Label("Start Session", systemImage: "record.circle")
                            .font(.headline)
                            .foregroundStyle(Theme.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.cheddar, in: Capsule())
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)  // just under the Home title; the rest of the page is for stats later
                }
                .navigationTitle(player.name.map { "Welcome, \($0)" } ?? "Home")
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Tab.home)

            NavigationStack {
                if guest {
                    LockedView(title: "Shot Map")
                } else {
                    ShotMapView()
                }
            }
            .tabItem { Label("Shot Map", systemImage: "scope") }
            .tag(Tab.shotMap)

            NavigationStack(path: $sessionsPath) {
                if guest {
                    LockedView(title: "Sessions")
                } else {
                    SessionsView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .session(let id):
                                if let session = store.session(id) {
                                    SessionDetailView(session: session)
                                }
                            }
                        }
                }
            }
            .tabItem { Label("Sessions", systemImage: "list.bullet") }
            .tag(Tab.sessions)

            NavigationStack {
                SettingsView(guest: guest, onSignedIn: onSignedIn, onAccountDeleted: onSignedOut)
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
            .tag(Tab.account)
        }
        .environment(store)
        .environment(\.speedRange, store.speedRange)
        .tint(Theme.cheddar)
        .fullScreenCover(isPresented: $turning) {
            TurnPhoneView {
                turnSideways()
                filming = true
            }
            .fullScreenCover(isPresented: $filming, onDismiss: {
                keepUpright()
                turning = false
            }) {
                RecordView(onSession: keepSession)
            }
        }
    }

    // A signed-in player's session is logged and opens on the Sessions tab. A guest's isn't kept: the camera shows its
    // speeds instead.
    private var keepSession: ((Session) -> Void)? {
        guard !guest else { return nil }
        return { session in
            store.log(session)
            sessionsPath = [.session(session.id)]
            tab = .sessions
            filming = false
        }
    }
}

#Preview {
    HomeView()
        .environment(PlayerName())
}
