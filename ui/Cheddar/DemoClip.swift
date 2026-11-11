import AVFoundation
import CVPipeline
import UIKit

/*
This file's only job is: list the demo clips bundled in the app and each shot Cheddar already read from them.
The numbers come from one real run of ClackShotReader on the 1x measured clips, saved ahead of time.
*/
struct DemoShot: Identifiable {
    let id: Int
    let time: Double        // seconds into the demo clip when the stick hits the puck
    let mph: Double?        // nil when Cheddar couldn't read the shot
    let square: NetSquare?
}

struct DemoClip: Identifiable {
    let id: String          // file name in DemoClips, without .mp4
    let title: String
    let shots: [DemoShot]

    var url: URL {
        Bundle.main.url(forResource: id, withExtension: "mp4")
            ?? Bundle.main.url(forResource: id, withExtension: "mp4", subdirectory: "DemoClips")!
    }

    // A frame from just before the first shot, for the clip's cover.
    func still() async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 720)
        let time = CMTime(seconds: max(0, (shots.first?.time ?? 1) - 0.5), preferredTimescale: 600)
        guard let image = try? await generator.image(at: time).image else { return nil }
        return UIImage(cgImage: image)
    }
}

extension DemoClip {
    static let all: [DemoClip] = [
        DemoClip(id: "43mph-54mph", title: "Clip 1", shots: [
            DemoShot(id: 1, time: 2.984, mph: 51.3, square: .bottomMiddle),
            DemoShot(id: 2, time: 8.547, mph: 57.2, square: .middleRight),
        ]),
        DemoClip(id: "54mph-52mph", title: "Clip 2", shots: [
            DemoShot(id: 1, time: 2.993, mph: 54.9, square: .bottomMiddle),
            DemoShot(id: 2, time: 10.128, mph: 55.7, square: .bottomMiddle),
        ]),
        DemoClip(id: "58mph-49mph", title: "Clip 3", shots: [
            DemoShot(id: 1, time: 2.985, mph: 63.8, square: .bottomLeft),
            DemoShot(id: 2, time: 7.852, mph: 60.2, square: .middleLeft),
        ]),
        DemoClip(id: "43mph-49mph", title: "Clip 4", shots: [
            DemoShot(id: 1, time: 2.981, mph: 48.3, square: .middleRight),
            DemoShot(id: 2, time: 7.774, mph: nil, square: nil),
        ]),
        DemoClip(id: "47mph-52mph", title: "Clip 5", shots: [
            DemoShot(id: 1, time: 3.006, mph: 60.7, square: .middle),
            DemoShot(id: 2, time: 7.339, mph: 59.6, square: .bottomMiddle),
        ]),
    ]
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
