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
    private static let minDarkening = 30

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
        let darkened = pixelsDarkened(in: middle)
        frames.append(SpotFrame(time: times[middle], spots: spots(in: darkened), changed: darkened.count { $0 }))
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

    private func pixelsDarkened(in middle: Int) -> [Bool] {
        let now = darkness[middle]
        let before = darkness[(middle - Self.framesToCompare + Self.framesKept) % Self.framesKept]
        let after = darkness[(middle + Self.framesToCompare) % Self.framesKept]
        return now.indices.map {
            min(Int(now[$0]) - Int(before[$0]), Int(now[$0]) - Int(after[$0])) > Self.minDarkening
        }
    }

    private func spots(in darkened: [Bool]) -> [Spot] {
        let width = columns.count
        var waiting = darkened
        var found: [Spot] = []
        for seed in waiting.indices where waiting[seed] {
            var stack = [seed], size = 0, totalX = 0, totalY = 0
            waiting[seed] = false
            while let pixel = stack.popLast() {
                let x = pixel % width, y = pixel / width
                size += 1
                totalX += x
                totalY += y
                let touching = [x > 0 ? pixel - 1 : nil, x + 1 < width ? pixel + 1 : nil,
                                y > 0 ? pixel - width : nil, pixel + width < waiting.count ? pixel + width : nil]
                for case let next? in touching where waiting[next] {
                    waiting[next] = false
                    stack.append(next)
                }
            }
            found.append(Spot(x: Double(totalX) / Double(size) + Double(columns.lowerBound),
                              y: Double(totalY) / Double(size) + Double(rows.lowerBound), size: size))
        }
        return found
    }
}
