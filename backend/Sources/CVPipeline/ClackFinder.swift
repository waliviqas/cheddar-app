import Foundation

/*
This class's only job is: take the mic's sound as it arrives and report the time of each stick-on-puck clack.
*/
public struct ClackFinder {
    private var audio = AudioSamples()
    private var lowCut = HighPass(cutoffHz: 2_000, rate: 48_000)

    // Filtered sound not yet grouped into a full 2 ms slice.
    private var pending: [Float] = []
    // Loudness of the most recent slices, used as the background to compare against.
    private var recentLoudness: [Float] = []

    private let sliceSize = 96            // 2 ms at 48,000 a second
    private let backgroundSlices = 500    // 1 s
    private let warmupSlices = 10
    private let timesLouder: Float = 16

    public init() {}

    // Adds one pack of sound and returns the times of any clacks found in it.
    public mutating func add(_ pack: [Float], startSeconds: Double) -> [Double] {
        audio.add(pack, startSeconds: startSeconds)
        pending += pack.map { lowCut.next($0) }

        var spot = audio.samples.count - pending.count
        var clacks: [Double] = []
        while pending.count >= sliceSize {
            let slice = pending.prefix(sliceSize)
            let loudness = (slice.reduce(0) { $0 + $1 * $1 } / Float(sliceSize)).squareRoot()
            let seconds = audio.time(at: spot)

            if recentLoudness.count >= warmupSlices {
                // The typical (middle) loudness, so one loud bang just before a shot doesn't hide it.
                let background = recentLoudness.sorted()[recentLoudness.count / 2]
                if loudness > timesLouder * max(background, 1e-4) {
                    clacks.append(seconds)
                }
            }

            recentLoudness.append(loudness)
            if recentLoudness.count > backgroundSlices {
                recentLoudness.removeFirst()
            }
            pending.removeFirst(sliceSize)
            spot += sliceSize
        }
        return clacks
    }
}

// Lets high-pitched sound through and strips out low rumble, one number at a time.
private struct HighPass {
    private let b0, b1, b2, a1, a2: Float
    private var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

    init(cutoffHz: Double, rate: Double) {
        let w = 2 * Double.pi * cutoffHz / rate
        let alpha = sin(w) / (2 * 0.7071)
        let a0 = 1 + alpha
        b0 = Float((1 + cos(w)) / 2 / a0)
        b1 = Float(-(1 + cos(w)) / a0)
        b2 = b0
        a1 = Float(-2 * cos(w) / a0)
        a2 = Float((1 - alpha) / a0)
    }

    mutating func next(_ x: Float) -> Float {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}
