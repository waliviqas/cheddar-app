import CoreVideo

struct Spot {
    let x: Double, y: Double
    let size: Int
}

struct SpotFrame {
    let time: Double
    let spots: [Spot]
    let changed: Int
}

/*
This class's only job is: find the dark moving spots in each video frame.

A pixel counts when it's darker than in the frames around it, so anything sitting still cancels out.
*/
struct TwoFramesBack {
    private static let framesKept = 9, framesEachSide = 4, framesToCompare = 2
    private static let minDarkening: Int16 = 30, minStrength: Int16 = 50
    private static let minSize = 20, maxSize = 1500, maxWidth = 100, maxHeight = 50

    let rows: Range<Int>, columns: Range<Int>
    private(set) var frames: [SpotFrame] = []
    private var darkness: [[UInt8]]
    private var times = [Double](repeating: 0, count: framesKept)
    private var framesSeen = 0

    init(rows: Range<Int>, columns: Range<Int>) {
        self.rows = rows
        self.columns = columns
        darkness = Array(repeating: [UInt8](repeating: 0, count: rows.count * columns.count), count: Self.framesKept)
    }

    mutating func add(_ frame: CVPixelBuffer, time: Double) {
        guard rows.lowerBound >= 0, columns.lowerBound >= 0,
              rows.upperBound <= CVPixelBufferGetHeight(frame),
              columns.upperBound <= CVPixelBufferGetWidth(frame) else { return }

        let slot = framesSeen % Self.framesKept
        storeDarkness(of: frame, in: slot)
        times[slot] = time
        framesSeen += 1
        guard framesSeen >= Self.framesKept else { return }

        let middle = (framesSeen - 1 - Self.framesEachSide) % Self.framesKept
        let darkening = pixelDarkening(in: middle)
        let changed = darkening.count { $0 > Self.minDarkening }
        frames.append(SpotFrame(time: times[middle], spots: spots(in: darkening), changed: changed))
    }

    // Black and blue pucks both have little red and green, so darkness ignores blue.
    private mutating func storeDarkness(of frame: CVPixelBuffer, in slot: Int) {
        let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
        let rowLength = CVPixelBufferGetBytesPerRow(frame), width = columns.count
        for (y, row) in rows.enumerated() {
            let start = pixels + row * rowLength + columns.lowerBound * 4
            for x in 0..<width {
                darkness[slot][y * width + x] = 255 - max(start[x * 4 + 1], start[x * 4 + 2])
            }
        }
    }

    private func pixelDarkening(in middle: Int) -> [Int16] {
        let now = darkness[middle]
        let before = darkness[comparison(to: middle, step: -1)]
        let after = darkness[comparison(to: middle, step: 1)]
        return now.indices.map {
            Int16(min(Int(now[$0]) - Int(before[$0]), Int(now[$0]) - Int(after[$0])))
        }
    }

    // Rink lights flicker 120 times a second, so compare frames at the same point in the flicker: one flicker away, else two.
    private func comparison(to middle: Int, step: Int) -> Int {
        for flickers in [1.0, 2.0] {
            for distance in 1...Self.framesEachSide {
                let frame = slot(middle + step * distance)
                if abs(abs(times[frame] - times[middle]) - flickers / 120) < 0.001 { return frame }
            }
        }
        return slot(middle + step * Self.framesToCompare)
    }

    private func slot(_ position: Int) -> Int {
        (position + Self.framesKept) % Self.framesKept
    }

    private func spots(in darkening: [Int16]) -> [Spot] {
        let width = columns.count
        var waiting = darkening.map { $0 > Self.minDarkening }
        var found: [Spot] = []
        for seed in waiting.indices where waiting[seed] {
            var stack = [seed], pixels: [Int] = []
            waiting[seed] = false
            while let pixel = stack.popLast() {
                pixels.append(pixel)
                let x = pixel % width, y = pixel / width
                for nextY in max(y - 1, 0)...min(y + 1, rows.count - 1) {
                    for nextX in max(x - 1, 0)...min(x + 1, width - 1) where waiting[nextY * width + nextX] {
                        waiting[nextY * width + nextX] = false
                        stack.append(nextY * width + nextX)
                    }
                }
            }
            if let spot = puckSizedSpot(from: pixels, darkening) { found.append(spot) }
        }
        return found
    }

    private func puckSizedSpot(from pixels: [Int], _ darkening: [Int16]) -> Spot? {
        guard (Self.minSize...Self.maxSize).contains(pixels.count) else { return nil }

        let across = pixels.map { $0 % columns.count }, down = pixels.map { $0 / columns.count }
        guard across.max()! - across.min()! < Self.maxWidth,
              down.max()! - down.min()! < Self.maxHeight else { return nil }

        // Most of the spot must darken clearly, so a faint shadow doesn't count.
        let strengths = pixels.map { darkening[$0] }
        guard strengths.sorted()[strengths.count * 9 / 10] >= Self.minStrength else { return nil }

        // Darker pixels pull the middle toward them, because a puck's blurred edge is only faintly dark.
        let total = strengths.reduce(0.0) { $0 + Double($1) }
        let x = zip(across, strengths).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / total
        let y = zip(down, strengths).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / total
        return Spot(x: x + Double(columns.lowerBound), y: y + Double(rows.lowerBound), size: pixels.count)
    }
}
