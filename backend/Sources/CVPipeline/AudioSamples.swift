/*
This class's only job is: collect the mic's sound numbers as they arrive, in order.
*/
public struct AudioSamples {
    public let rate: Double = 48_000
    public let keepSeconds: Double = 3
    public private(set) var samples: [Float] = []
    private var oldestSeconds: Double = 0

    public init() {}

    public func time(at spot: Int) -> Double {
        oldestSeconds + Double(spot) / rate
    }

    public mutating func add(_ pack: [Float], startSeconds: Double) {
        if samples.isEmpty {
            oldestSeconds = startSeconds
        }
        samples.append(contentsOf: pack)
        let limit = Int(rate * keepSeconds)
        if samples.count > limit {
            let extra = samples.count - limit
            samples.removeFirst(extra)
            oldestSeconds += Double(extra) / rate
        }
    }
}
