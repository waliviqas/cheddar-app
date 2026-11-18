import Foundation

typealias Vec2 = SIMD2<Double>

/*
This class's only job is: move the 4 corner taps onto the net's true inside corners.

Taps land a few pixels off, so straight lines fitted to the posts and crossbar find the real corners.
Size limits are shares of how tall a post looks, so they adjust to where the phone is.
*/
enum NetCorners {
    private static let minWidthShare = 0.015, maxWidthShare = 0.11, searchShare = 0.1
    private static let searchBoxShare = 0.2, maxMoveShare = 0.05
    private static let postCornerShare = 0.08, barCornerShare = 0.12

    // x = a + b * y for posts, y = a + b * x for the crossbar.
    struct Line {
        var a = 0.0, b = 0.0

        func at(_ position: Double) -> Double {
            a + b * position
        }
    }

    struct Mask {
        let width: Int, height: Int
        var on: [Bool]

        func at(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && y >= 0 && x < width && y < height && on[y * width + x]
        }
    }

    // Taps go top-left, top-right, bottom-right, bottom-left. No answer means the app should keep the taps.
    static func refine(_ taps: [Vec2], picture: Picture) -> [Vec2]? {
        guard taps.count == 4 else { return nil }
        let postHeight = tallestPost(taps)
        let mask = postMask(picture, around: taps)
        guard let left = postEdges(mask, top: taps[0], bottom: taps[3]),
              let right = postEdges(mask, top: taps[1], bottom: taps[2]),
              let bar = barBottom(mask, left: taps[0], right: taps[1], postHeight: postHeight) else { return nil }

        // The opening's inside edges are the left post's right edge and the right post's left edge.
        let corners = [meet(post: left.right, bar: bar), meet(post: right.left, bar: bar),
                       Vec2(right.left.at(taps[2].y), taps[2].y), Vec2(left.right.at(taps[3].y), taps[3].y)]
        let maxMove = postHeight * maxMoveShare
        return zip(corners, taps).allSatisfy { hypot($0.x - $1.x, $0.y - $1.y) <= maxMove } ? corners : nil
    }

    static func meet(post: Line, bar: Line) -> Vec2 {
        let x = (post.a + post.b * bar.a) / (1 - post.b * bar.b)
        return Vec2(x, bar.at(x))
    }

    // Fits a straight line, then refits it without the points that sit far from the rest.
    static func robustLine(_ points: [(t: Double, v: Double)]) -> Line? {
        var kept = points
        var line = Line()
        for _ in 0..<4 {
            guard kept.count >= 10 else { return nil }
            let fit = Solver.polyfit(kept.map(\.t), kept.map(\.v), degree: 1)
            line = Line(a: fit[0], b: fit[1])
            let misses = kept.map { abs($0.v - line.at($0.t)) }
            let typicalMiss = misses.sorted()[misses.count / 2] * 1.4826 + 1e-6
            kept = zip(kept, misses).filter { $0.1 < max(2.5 * typicalMiss, 0.75) }.map(\.0)
        }
        return line
    }

    // The stretch of frame pixels nearest the guess, if it's a believable width for a post this tall.
    static func nearestRun(_ guess: Int, postHeight: Double, along isOn: (Int) -> Bool) -> (Int, Int)? {
        let reach = Int((postHeight * searchShare).rounded())
        var best: (Int, Int)?, bestDistance = Int.max
        var index = guess - reach
        while index <= guess + reach {
            if isOn(index) {
                let start = index
                while index + 1 <= guess + reach * 3 / 2, isOn(index + 1) { index += 1 }
                let distance = abs((start + index) / 2 - guess)
                if distance < bestDistance {
                    bestDistance = distance
                    best = (start, index)
                }
            }
            index += 1
        }
        guard let (start, end) = best else { return nil }
        let width = Double(end - start + 1)
        return width >= postHeight * minWidthShare && width <= postHeight * maxWidthShare ? (start, end) : nil
    }

    // Marks the pixels near the taps that could be the frame: red in sun, red in blue shade, or very dark.
    static func postMask(_ picture: Picture, around taps: [Vec2]) -> Mask {
        var on = [Bool](repeating: false, count: picture.width * picture.height)
        let pad = (tallestPost(taps) * searchBoxShare).rounded()
        let across = taps.map(\.x), down = taps.map(\.y)
        let left = max(0, Int(across.min()! - pad)), right = min(picture.width, Int(across.max()! + pad))
        let top = max(0, Int(down.min()! - pad)), bottom = min(picture.height, Int(down.max()! + pad))
        guard left < right, top < bottom else { return Mask(width: picture.width, height: picture.height, on: on) }

        for y in top..<bottom {
            for x in left..<right {
                guard let (r, g, b) = picture.color(x, y) else { continue }
                let brightness = (r + g + b) / 3
                on[y * picture.width + x] = ((r + b) / 2 - g >= 10 && r - g >= 8 && brightness < 150) || brightness < 30
            }
        }
        return Mask(width: picture.width, height: picture.height, on: on)
    }

    // Walks down a post between its two taps, skipping the rounded corners, and measures both edges in each row.
    static func postEdges(_ mask: Mask, top: Vec2, bottom: Vec2) -> (left: Line, right: Line)? {
        let postHeight = abs(bottom.y - top.y)
        guard postHeight > 0 else { return nil }
        let skip = (postHeight * postCornerShare).rounded()

        var lefts: [(t: Double, v: Double)] = [], rights: [(t: Double, v: Double)] = []
        for y in Int(top.y + skip)...max(Int(top.y + skip), Int(bottom.y - skip)) {
            let guess = Int((top.x + (Double(y) - top.y) / (bottom.y - top.y) * (bottom.x - top.x)).rounded())
            guard let (start, end) = nearestRun(guess, postHeight: postHeight, along: { mask.at($0, y) }) else { continue }
            lefts.append((Double(y), Double(start) - 0.5))
            rights.append((Double(y), Double(end) + 0.5))
        }
        guard let left = robustLine(lefts), let right = robustLine(rights) else { return nil }
        return (left, right)
    }

    // Walks across the crossbar between the two top taps, skipping the rounded corners, and measures its lower edge.
    static func barBottom(_ mask: Mask, left: Vec2, right: Vec2, postHeight: Double) -> Line? {
        let barLength = abs(right.x - left.x)
        guard barLength > 0 else { return nil }
        let skip = (barLength * barCornerShare).rounded()

        var bottoms: [(t: Double, v: Double)] = []
        for x in Int(left.x + skip)...max(Int(left.x + skip), Int(right.x - skip)) {
            let guess = Int((left.y + (Double(x) - left.x) / (right.x - left.x) * (right.y - left.y)).rounded())
            guard let (_, end) = nearestRun(guess, postHeight: postHeight, along: { mask.at(x, $0) }) else { continue }
            bottoms.append((Double(x), Double(end) + 0.5))
        }
        return robustLine(bottoms)
    }

    private static func tallestPost(_ taps: [Vec2]) -> Double {
        max(abs(taps[3].y - taps[0].y), abs(taps[2].y - taps[1].y))
    }
}
