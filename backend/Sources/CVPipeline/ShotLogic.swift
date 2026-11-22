import Foundation

/*
This class's only job is: read each shot while the camera is still filming, from the spots one frame at a time, and write a
note for each shot.

It uses the after-Stop reader's rules and numbers (ShotFinder, PuckTrack, ShotFit and ShotReader's keep rules). A shot is
decided only when nothing can change its reading any more, and its note says to say it out loud only when it's a real shot
and no camera frame was lost near it, so live never says a number the after-Stop read wouldn't.
*/
struct ShotLogic {
    // One shot: its speed (none if the speed math couldn't find one), whether it's a real shot (on the net, 5 to 130 mph),
    // and how many camera frames were lost near it.
    struct Note {
        let reading: ShotReading?
        let kept: Bool
        let framesLost: Int
        let capped: Bool  // decided by the 0.15 s limit while a spot could still have joined
        let decidedAt: Double

        var said: Bool { kept && framesLost == 0 }
    }

    private static let safetyCap = 0.15, historySeconds = 3.0, steadyStart = 1.0, typicalSeconds = 10.0
    // A lost frame changes the spots up to 4 frames on each side of it, since the spotter compares the middle of 9.
    private static let lostReach = 6.0 / 240

    private(set) var notes: [Note] = []
    private let pose: CameraPose, scale: Double, direction: Double, laneX: ClosedRange<Double>
    private var history: [SpotFrame] = []
    private var recentChanged: [(time: Double, changed: Int)] = []
    private var changedSorted: [Int] = []
    private var firstTime: Double?
    private var following: [[TrackPoint]] = []
    private var parts: [[TrackPoint]] = []
    private var closedUntil = -Double.infinity
    private var gaps: [(from: Double, to: Double, lost: Int)] = []
    private var frameTime = 0.0

    // laneX: the search strip's columns, which spots never leave.
    init(pose: CameraPose, scale: Double, laneX: ClosedRange<Double>) {
        self.pose = pose
        self.scale = scale
        self.laneX = laneX
        direction = ShotReader.towardNet(pose)
    }

    // Camera frames were lost between two frames that arrived.
    mutating func noteGap(from: Double, to: Double, lost: Int) {
        gaps.append((from, to, lost))
    }

    // frameTime: the newest camera frame's time (the spot frame is for a frame 4 frames earlier).
    mutating func feed(_ frame: SpotFrame, frameTime: Double) {
        self.frameTime = frameTime
        history.append(frame)
        if history.count > 1200, let cut = history.firstIndex(where: { $0.time >= frame.time - Self.historySeconds }), cut > 240 {
            history.removeFirst(cut)
        }
        let limit = bumpLimit(adding: frame)
        follow(frame.changed > limit ? [] : frame.spots, at: frame.time)
        decide(at: frame.time)
    }

    // A bumped phone changes far more pixels than usual, and usual is the middle of the last 10 s. The first second always
    // uses the 5,000 floor, so the shake from tapping Record is caught.
    private mutating func bumpLimit(adding frame: SpotFrame) -> Int {
        let start = firstTime ?? frame.time
        firstTime = start
        recentChanged.append((frame.time, frame.changed))
        changedSorted.insert(frame.changed, at: firstIndex(atLeast: frame.changed))
        while let oldest = recentChanged.first, oldest.time < frame.time - Self.typicalSeconds {
            recentChanged.removeFirst()
            changedSorted.remove(at: firstIndex(atLeast: oldest.changed))
        }
        guard frame.time >= start + Self.steadyStart else { return ShotFinder.minBumpPixels }
        return max(ShotFinder.minBumpPixels, ShotFinder.bumpTimesTypical * changedSorted[changedSorted.count / 2])
    }

    private func firstIndex(atLeast value: Int) -> Int {
        var low = 0, high = changedSorted.count
        while low < high {
            let middle = (low + high) / 2
            if changedSorted[middle] >= value { high = middle } else { low = middle + 1 }
        }
        return low
    }

    // ShotFinder.link, one frame at a time. A path that's finished is checked for a fast part toward the net.
    private mutating func follow(_ spots: [Spot], at time: Double) {
        var unclaimed = [Bool](repeating: true, count: spots.count)
        for index in following.indices.sorted(by: { following[$0].count > following[$1].count }) {
            guard let spot = ShotFinder.nearestSpot(for: following[index], at: time, in: spots, unclaimed) else { continue }
            unclaimed[spot] = false
            following[index].append(TrackPoint(t: time, x: spots[spot].x, y: spots[spot].y))
        }
        let done = following.filter { time - $0.last!.t > ShotFinder.maxUnseen }
        following.removeAll { time - $0.last!.t > ShotFinder.maxUnseen }
        for (index, spot) in spots.enumerated() where unclaimed[index] {
            following.append([TrackPoint(t: time, x: spot.x, y: spot.y)])
        }
        for path in done {
            // A piece starting inside a shot that's already decided can't change it any more.
            guard let part = ShotFinder.fastPart(path, towardNet: direction), part[0].t > closedUntil else { continue }
            parts.append(part)
        }
    }

    // Decides the oldest open shot once no new piece can join it and all its frames are in.
    private mutating func decide(at time: Double) {
        let window = ShotFinder.sameShotWindow
        while !parts.isEmpty {
            parts.sort { $0[0].t < $1[0].t }
            var count = 1
            while count < parts.count, parts[count][0].t <= parts[count - 1].last!.t + window { count += 1 }
            let pieces = Array(parts[0..<count])
            let anchor = pieces.last!.last!.t
            guard time > anchor + window else { return }
            let chosen = pieces.max { (ShotFinder.travel($0, direction), $0.count) < (ShotFinder.travel($1, direction), $1.count) }!
            let end = max(chosen[0].t + PuckTrack.secondsAfterStart, chosen.last!.t + PuckTrack.secondsAfterEnd)
            var capped = false
            if following.contains(where: { mightJoin($0, by: anchor + window) }) {
                guard time >= max(anchor + window, end) + Self.safetyCap else { return }
                capped = true
            }
            guard time >= end else { return }

            let trackFrom = chosen[0].t - PuckTrack.secondsBefore
            // A lost frame inside any piece could change which piece is chosen, so losses count from the earliest piece.
            let windowStart = pieces[0][0].t - PuckTrack.secondsBefore
            let recent = history.filter { $0.time >= trackFrom - 0.01 }
            let fit = PuckTrack.exact(Flight(points: chosen), frames: recent, towardNet: direction).flatMap { ShotFit.read($0, pose: pose) }
            let lost = gaps.filter { $0.to > windowStart - Self.lostReach && $0.from < frameTime }.reduce(0) { $0 + $1.lost }
            notes.append(Note(reading: fit.map { ShotReading(releaseTime: $0.releaseTime, mph: $0.mph, hit: $0.hit, slid: $0.slid) },
                              kept: fit.map { ShotReader.keeps($0, scale: scale) } ?? false,
                              framesLost: lost, capped: capped, decidedAt: time))
            closedUntil = anchor + window
            parts.removeFirst(count)
        }
    }

    // Could this path, still being followed, end up with a fast part that starts by `limit`?
    private func mightJoin(_ path: [TrackPoint], by limit: Double) -> Bool {
        guard path[0].t <= limit else { return false }
        if path.last!.t <= limit && canStillTravel(path, from: path.count - 1) { return true }
        var step = 0
        while step < path.count - 1 {
            guard isFast(path, step) else { step += 1; continue }
            var end = step + 1
            while end < path.count - 1, isFast(path, end) { end += 1 }
            if path[step].t <= limit {
                if end == path.count - 1 {
                    if canStillTravel(path, from: step) { return true }
                } else {
                    let run = Array(path[step...end])
                    if run.count >= ShotFinder.minSightings && ShotFinder.travel(run, direction) >= ShotFinder.minTravel { return true }
                }
            }
            step = end
        }
        return false
    }

    private func isFast(_ path: [TrackPoint], _ step: Int) -> Bool {
        let from = path[step], to = path[step + 1]
        return hypot(to.x - from.x, to.y - from.y) / (to.t - from.t) >= ShotFinder.minSpeed
    }

    // Spots never leave the strip, so a path near its net-side edge can't still travel the 600 px a shot needs.
    private func canStillTravel(_ path: [TrackPoint], from start: Int) -> Bool {
        let last = path.last!
        let soFar = direction * (last.x - path[start].x)
        let room = direction > 0 ? laneX.upperBound - last.x : last.x - laneX.lowerBound
        return soFar + room >= ShotFinder.minTravel
    }
}
