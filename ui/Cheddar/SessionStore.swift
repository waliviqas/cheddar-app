import Observation

/*
This class's only job is: keep the list of logged sessions, newest first.
*/
@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [Session] = [Demo.oct23]
    private(set) var justLogged: Session.ID?

    func log(_ session: Session) {
        sessions.insert(session, at: 0)
        justLogged = session.id
    }

    // Back to how the demo starts: only the Oct 23 session.
    func reset() {
        sessions = [Demo.oct23]
        justLogged = nil
    }

    func session(_ id: Session.ID) -> Session? {
        sessions.first { $0.id == id }
    }
}
