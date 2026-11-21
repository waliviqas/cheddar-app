import Foundation
import Supabase

/*
This file's only job is: send a signed-in player's finished session to Supabase as plain numbers, so Cheddar can learn
from real shots. The video isn't sent; it stays in the player's iCloud.
*/
enum SessionUpload {
    static func send(_ session: Session) async throws {
        try await supabase.from("sessions").insert(SessionRow(session)).execute()
        try await supabase.from("shots").insert(session.shots.map { ShotRow($0, of: session) }).execute()
    }
}

// Supabase fills in user_id from whoever is signed in.
private struct SessionRow: Encodable {
    let id: UUID
    let recordedAt: Date
    let lengthSeconds: Double

    init(_ session: Session) {
        id = session.id
        recordedAt = session.date
        lengthSeconds = session.duration
    }

    enum CodingKeys: String, CodingKey {
        case id
        case recordedAt = "recorded_at"
        case lengthSeconds = "length_seconds"
    }
}

private struct ShotRow: Encodable {
    let sessionID: UUID
    let number: Int
    let mph: Double?
    let square: String?
    let timeInVideo: Double

    init(_ shot: Shot, of session: Session) {
        sessionID = session.id
        number = shot.id
        mph = shot.mph
        square = shot.square.map { "\($0)" }
        timeInVideo = shot.clack
    }

    enum CodingKeys: String, CodingKey {
        case number, mph, square
        case sessionID = "session_id"
        case timeInVideo = "time_in_video"
    }
}
