import CVPipeline
import Foundation

/*
This file's only job is: say what a session and a shot are, and how they're written to a file, so a signed-in player's
sessions are still there after the app closes.
*/
struct Shot: Identifiable {
    let id: Int
    let mph: Double?         // nil when Cheddar couldn't read the shot
    let square: NetSquare?
    var clip: String? = nil  // this shot's replay clip, a file in SavedVideos
    var clack: Double = 0    // seconds into the session video when the stick hits the puck
}

struct Session: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let shots: [Shot]
    let duration: TimeInterval
    var video: String? = nil  // the whole session's video, a file in SavedVideos

    var speeds: [Double] { shots.compactMap(\.mph) }
    var topSpeed: Double? { speeds.max() }
    var average: Double? { speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count) }
}

// The square is saved by its name, like "topLeft", since NetSquare comes from the shot reader.
extension Shot: Codable {
    private enum Keys: String, CodingKey { case id, mph, square, clip, clack }

    init(from decoder: Decoder) throws {
        let saved = try decoder.container(keyedBy: Keys.self)
        id = try saved.decode(Int.self, forKey: .id)
        mph = try saved.decodeIfPresent(Double.self, forKey: .mph)
        square = try saved.decodeIfPresent(String.self, forKey: .square).flatMap(NetSquare.named)
        clip = try saved.decodeIfPresent(String.self, forKey: .clip)
        clack = try saved.decode(Double.self, forKey: .clack)
    }

    func encode(to encoder: Encoder) throws {
        var saved = encoder.container(keyedBy: Keys.self)
        try saved.encode(id, forKey: .id)
        try saved.encodeIfPresent(mph, forKey: .mph)
        try saved.encodeIfPresent(square.map { "\($0)" }, forKey: .square)
        try saved.encodeIfPresent(clip, forKey: .clip)
        try saved.encode(clack, forKey: .clack)
    }
}

extension NetSquare {
    private static let all: [NetSquare] = [.topLeft, .topMiddle, .topRight, .middleLeft, .middle, .middleRight,
                                           .bottomLeft, .bottomMiddle, .bottomRight, .post, .missed]

    // The square with that saved name, like "topLeft".
    static func named(_ name: String) -> NetSquare? {
        all.first { "\($0)" == name }
    }

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
        case .middle: "Middle"
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
