import CVPipeline
import Foundation

/*
This file's only job is: say what a session and a shot are, and where the player's own videos of them are kept on
this phone.
*/
struct Shot: Identifiable {
    let id: Int
    let mph: Double?         // nil when Cheddar couldn't read the shot
    let square: NetSquare?
    var clip: String? = nil  // this shot's replay clip, a file in SavedVideos
    var clack: Double = 0    // seconds into the session video when the stick hits the puck
}

struct Session: Identifiable {
    let id = UUID()
    let date: Date
    let shots: [Shot]
    let duration: TimeInterval
    var video: String? = nil  // the whole session's video, a file in SavedVideos

    var speeds: [Double] { shots.compactMap(\.mph) }
    var topSpeed: Double? { speeds.max() }
    var average: Double? { speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count) }
}

// The player's own videos live in the app's private Videos folder on this phone, which other apps can't open.
enum SavedVideos {
    static let folder = URL.applicationSupportDirectory.appending(path: "Videos", directoryHint: .isDirectory)

    // The saved video with that file name, or nil when it isn't on this phone.
    static func url(_ name: String) -> URL? {
        let url = folder.appending(path: name)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }
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
