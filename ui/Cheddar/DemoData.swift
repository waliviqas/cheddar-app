import CVPipeline
import Foundation

/*
This file's only job is: hold the demo's shots and sessions.
Today's session is the first 5 measured shots, silent; speeds and squares are real reads from one ClackShotReader run.
The Oct 23 session is the ten 1x shots with their radar speeds; their squares are filled in for the demo.
Every shot has a short silent replay clip in DemoClips.
*/
struct Shot: Identifiable {
    let id: Int
    let mph: Double?         // nil when Cheddar couldn't read the shot
    let square: NetSquare?
    var clip: String? = nil  // replay video in DemoClips, without .mp4
    var clack: Double = 0    // seconds into the session video when the stick hits the puck
}

struct Session: Identifiable {
    let id = UUID()
    let date: Date
    let cover: String        // image in the asset catalog
    let shots: [Shot]
    let duration: TimeInterval

    var speeds: [Double] { shots.compactMap(\.mph) }
    var topSpeed: Double? { speeds.max() }
    var average: Double? { speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count) }
}

enum Demo {
    static func video(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4")
            ?? Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "DemoClips")
    }

    static var sessionVideo: URL { video("session")! }

    // In every replay clip the stick hits the puck about this far in.
    static let replayShotAt = 2.2

    static let liveShots: [Shot] = [
        Shot(id: 1, mph: 51.3, square: .bottomMiddle, clip: "shot-nov11-1", clack: 2.984),
        Shot(id: 2, mph: 57.2, square: .middleRight, clip: "shot-nov11-2", clack: 8.547),
        Shot(id: 3, mph: 54.9, square: .bottomMiddle, clip: "shot-nov11-3", clack: 14.093),
        Shot(id: 4, mph: 55.7, square: .bottomMiddle, clip: "shot-nov11-4", clack: 21.228),
        Shot(id: 5, mph: 63.8, square: .bottomLeft, clip: "shot-nov11-5", clack: 26.785),
    ]

    // Where the net's inside corners sit in each clip of the session video (1920 × 1080, y down),
    // from Wali's clicks: left top, right top, right bottom, left bottom.
    static let netCorners: [(from: Double, corners: [CGPoint])] = [
        (0, [CGPoint(x: 1503, y: 608), CGPoint(x: 1730, y: 645), CGPoint(x: 1722, y: 1046), CGPoint(x: 1488, y: 894)]),
        (11.1, [CGPoint(x: 1503, y: 617), CGPoint(x: 1729, y: 654), CGPoint(x: 1721, y: 1054), CGPoint(x: 1486, y: 903)]),
        (23.8, [CGPoint(x: 1505, y: 614), CGPoint(x: 1733, y: 654), CGPoint(x: 1724, y: 1054), CGPoint(x: 1488, y: 899)]),
    ]
    static let videoSize = CGSize(width: 1920, height: 1080)

    static func netCorners(at seconds: Double) -> [CGPoint] {
        netCorners.last { seconds >= $0.from }?.corners ?? netCorners[0].corners
    }

    // The 1x clips from Oct 23 in the order they were filmed: 58-54, 41-49, 49-49 (third shot), 49-49, 45-40.
    static let oct23: Session = {
        let speeds: [Double] = [58, 54, 41, 49, 49, 49, 49, 49, 45, 40]
        let squares: [NetSquare] = [.bottomLeft, .middle, .bottomMiddle, .topRight, .middleRight,
                                    .middleRight, .bottomMiddle, .middleLeft, .topLeft, .bottomRight]
        let shots = speeds.indices.map { i in
            Shot(id: i + 1, mph: speeds[i], square: squares[i], clip: "shot-oct23-\(i + 1)")
        }
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 15, minute: 0)) ?? .now
        return Session(date: date, cover: "SessionOct23", shots: shots, duration: 13 * 60)
    }()
}

extension NetSquare {
    // Row and column in the 3 × 3 grid, top-left is (0, 0); nil for the post or a miss.
    var cell: (row: Int, column: Int)? {
        switch self {
        case .topLeft: (0, 0)
        case .topMiddle: (0, 1)
        case .topRight: (0, 2)
        case .middleLeft: (1, 0)
        case .middle: (1, 1)
        case .middleRight: (1, 2)
        case .bottomLeft: (2, 0)
        case .bottomMiddle: (2, 1)
        case .bottomRight: (2, 2)
        case .post, .missed: nil
        }
    }

    var label: String {
        switch self {
        case .topLeft: "Top left"
        case .topMiddle: "Top middle"
        case .topRight: "Top right"
        case .middleLeft: "Middle left"
        case .middle: "Five hole"
        case .middleRight: "Middle right"
        case .bottomLeft: "Bottom left"
        case .bottomMiddle: "Bottom middle"
        case .bottomRight: "Bottom right"
        case .post: "Post"
        case .missed: "Missed"
        }
    }
}

extension TimeInterval {
    // 83 → "1:23"
    var clock: String { String(format: "%d:%02d", Int(self) / 60, Int(self) % 60) }

    // 54 → "54 sec", 1500 → "25 min"
    var length: String { self < 60 ? "\(Int(self)) sec" : "\(Int(self / 60)) min" }
}

extension Optional where Wrapped == Double {
    // 57.24 → "57.2", nil → "—"
    var mphText: String { map { String(format: "%.1f", $0) } ?? "—" }
}
