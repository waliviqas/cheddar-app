import Foundation
import Testing
@testable import CVPipeline

@Suite("Solver")
struct SolverTests {

    @Test("solves 2 equations")
    func twoEquations() {
        #expect(isClose(Solver.solveLinear([[1, 1, 3], [1, -1, 1]]), to: [2, 1]))
    }

    @Test("solves 1 equation")
    func oneEquation() {
        #expect(isClose(Solver.solveLinear([[2, 8]]), to: [4]))
    }

    @Test("solves 8 equations")
    func eightEquations() {
        let answer = [0.004, 0.0002, -0.15, 0.0006, -0.0045, 0.12, 0.0009, 0.00005]
        let netCorners: [(across: Double, up: Double)] = [(0, 48), (72, 48), (72, 0), (0, 0)]
        var rows: [[Double]] = []
        for (across, up) in netCorners {
            let depth = answer[6] * across + answer[7] * up + 1
            let seenX = (answer[0] * across + answer[1] * up + answer[2]) / depth
            let seenY = (answer[3] * across + answer[4] * up + answer[5]) / depth
            rows.append([across, up, 1, 0, 0, 0, -seenX * across, -seenX * up, seenX])
            rows.append([0, 0, 0, across, up, 1, -seenY * across, -seenY * up, seenY])
        }

        #expect(isClose(Solver.solveLinear(rows), to: answer))
    }

    @Test("no equations returns an empty answer")
    func noEquations() {
        #expect(Solver.solveLinear([]) == [])
    }

    @Test("a zero in the first position still solves")
    func zeroInFirstPosition() {
        #expect(isClose(Solver.solveLinear([[0, 1, 2], [1, 0, 3]]), to: [3, 2]))
    }

    @Test("very large and very small numbers together still solve")
    func largeAndSmallNumbers() {
        #expect(isClose(Solver.solveLinear([[1e200, 0, 1e200], [0, 1e-200, 1e-200]]), to: [1, 1]))
    }

    @Test("all zeros returns no answer")
    func allZeros() {
        #expect(Solver.solveLinear([[0, 0, 0], [0, 0, 0]]) == nil)
    }

    @Test("two equations that say the same thing return no answer")
    func sameEquationTwice() {
        #expect(Solver.solveLinear([[1, 2, 3], [2, 4, 6]]) == nil)
    }

    @Test("an equation hidden in the other two returns no answer")
    func hiddenEquation() {
        #expect(Solver.solveLinear([[1, 2, 3, 1], [4, 5, 6, 2], [7, 8, 9, 3]]) == nil)
    }

    @Test("three equations that contradict each other return no answer")
    func contradictingEquations() {
        #expect(Solver.solveLinear([[1, 2, 3, 1], [4, 5, 6, 2], [7, 8, 9, 4]]) == nil)
    }

    @Test("two almost identical equations return no answer")
    func almostIdenticalEquations() {
        #expect(Solver.solveLinear([[1, 1, 2], [1, 1 + 1e-15, 3]]) == nil)
    }

    @Test("NaN in the equations returns no answer")
    func notANumberInEquations() {
        #expect(Solver.solveLinear([[.nan, 1, 2], [1, 1, 2]]) == nil)
    }

    @Test("an infinite number in the equations returns no answer")
    func infiniteNumberInEquations() {
        #expect(Solver.solveLinear([[.infinity, 1, 2], [1, 1, 2]]) == nil)
    }

    @Test("NaN on the right side returns no answer")
    func notANumberOnRightSide() {
        #expect(Solver.solveLinear([[1, 0, .nan], [0, 1, 2]]) == nil)
    }

    @Test("rows that are too short return no answer")
    func rowsTooShort() {
        #expect(Solver.solveLinear([[1, 2], [3, 4]]) == nil)
    }

    @Test("fits a perfect straight line")
    func perfectStraightLine() {
        #expect(isClose(Solver.polyfit([0, 1, 2, 3], [1, 3, 5, 7], degree: 1), to: [1, 2]))
    }

    @Test("fits a perfect curve")
    func perfectCurve() {
        #expect(isClose(Solver.polyfit([0, 1, 2, 3, 4], [1, 2, 5, 10, 17], degree: 2), to: [1, 0, 1]))
    }

    @Test("a flat fit returns the average")
    func flatFit() {
        #expect(isClose(Solver.polyfit([0, 1, 2], [2, 4, 6], degree: 0), to: [4]))
    }

    @Test("fits a curve through exactly 3 points")
    func exactlyThreePoints() {
        #expect(isClose(Solver.polyfit([0, 1, 2], [1, 2, 5], degree: 2), to: [1, 0, 1]))
    }

    @Test("fits 48 frames of a puck at 240 fps")
    func fortyEightFrames() {
        let times = (0..<48).map { Double($0) / 240 }
        let fit = Solver.polyfit(times, times.map { 5 + 88 * $0 - 16 * $0 * $0 }, degree: 2)

        #expect(isClose(fit, to: [5, 88, -16]))
    }

    @Test("finds the true line through evenly balanced wobble")
    func balancedWobble() {
        #expect(isClose(Solver.polyfit([0.1, 0.2, 0.3], [10.9, 19.4, 28.5], degree: 1), to: [2, 88]))
    }

    @Test("times far from zero stay accurate")
    func timesFarFromZero() {
        let times = (0..<50).map { 1_000_000 + Double($0) / 240 }
        let fit = Solver.polyfit(times, times.map { 2 + 3 * ($0 - 1_000_000) }, degree: 2)

        #expect(abs(Solver.polyval(fit, times[25]) - (2 + 3 * (times[25] - 1_000_000))) <= 0.001)
    }

    @Test("too few points returns no answer")
    func tooFewPoints() {
        #expect(isNoAnswer(Solver.polyfit([0, 1], [1, 2], degree: 2), size: 3))
    }

    @Test("no points returns no answer")
    func noPoints() {
        #expect(isNoAnswer(Solver.polyfit([], [], degree: 1), size: 2))
    }

    @Test("points that all share one time return no answer")
    func allSameTime() {
        #expect(isNoAnswer(Solver.polyfit([1, 1, 1], [1, 2, 3], degree: 1), size: 2))
    }

    @Test("an unreadable measurement returns no answer")
    func unreadableMeasurement() {
        #expect(isNoAnswer(Solver.polyfit([0, 1, 2], [1, .nan, 3], degree: 1), size: 2))
    }

    @Test("fewer measurements than times returns no answer")
    func fewerMeasurements() {
        #expect(isNoAnswer(Solver.polyfit([0, 1, 2], [1, 2], degree: 1), size: 2))
    }

    @Test("more measurements than times returns no answer")
    func moreMeasurements() {
        #expect(isNoAnswer(Solver.polyfit([0, 1], [1, 2, 99], degree: 1), size: 2))
    }

    @Test("a negative curve size returns an empty answer")
    func negativeCurveSize() {
        #expect(Solver.polyfit([0, 1], [1, 2], degree: -1) == [])
    }

    @Test("reading from nothing returns 0")
    func readFromNothing() {
        #expect(Solver.polyval([], 3) == 0)
    }

    @Test("reading at time 0 returns the first number")
    func readAtTimeZero() {
        #expect(Solver.polyval([5, 88, -16], 0) == 5)
    }

    @Test("reading at a negative time works the fit backward")
    func readAtNegativeTime() {
        #expect(Solver.polyval([1, 2, 3], -2) == 9)
    }

    @Test("reading back a measured point matches it")
    func readBackMeasuredPoint() {
        let times = [0.0, 1, 2, 3, 4], heights = [1.0, 2, 5, 10, 17]
        let fit = Solver.polyfit(times, heights, degree: 2)

        #expect(isClose(times.map { Solver.polyval(fit, $0) }, to: heights))
    }

    @Test("solves a simple straight-line problem")
    func simpleLineProblem() {
        let result = Solver.leastSquares([0, 0], steps: [1e-4, 1e-4]) { guess in
            (0..<5).map { guess[0] + guess[1] * Double($0) - (2 + 3 * Double($0)) }
        }

        #expect(isClose(result.answer, to: [2, 3], within: 1e-6))
    }

    @Test("solves a hard curved problem")
    func hardCurvedProblem() {
        let result = Solver.leastSquares([-1.2, 1], steps: [1e-6, 1e-6], iterations: 500) { guess in
            [10 * (guess[1] - guess[0] * guess[0]), 1 - guess[0]]
        }

        #expect(isClose(result.answer, to: [1, 1], within: 1e-4))
    }

    @Test("a perfect starting guess stays put")
    func perfectStart() {
        let result = Solver.leastSquares([2], steps: [1e-4]) { guess in [guess[0] - 2] }

        #expect(result.answer == [2])
        #expect(result.error == 0)
    }

    @Test("noisy data ends with less error than it started with")
    func noisyData() {
        let noise = [0.1, -0.2, 0.15, -0.05, 0.08, -0.12]
        let misses: ([Double]) -> [Double] = { guess in
            noise.indices.map { guess[0] * exp(guess[1] * Double($0)) - (2 * exp(0.3 * Double($0)) + noise[$0]) }
        }
        let startingError = misses([1, 0.1]).reduce(0) { $0 + $1 * $1 }

        let result = Solver.leastSquares([1, 0.1], steps: [1e-5, 1e-5], misses)

        #expect(result.error < startingError)
    }

    @Test("handles values of very different sizes")
    func veryDifferentSizes() {
        let result = Solver.leastSquares([1, 1], steps: [1e-7, 1e-1]) { guess in
            [1e4 * (guess[0] - 0.002), 1e-3 * (guess[1] - 3000)]
        }

        #expect(abs(result.answer[0] - 0.002) <= 1e-6)
        #expect(abs(result.answer[1] - 3000) <= 1e-3)
    }

    @Test("more unknowns than clues still matches every clue")
    func moreUnknownsThanClues() {
        let result = Solver.leastSquares([0, 0], steps: [1e-4, 1e-4]) { guess in [guess[0] + guess[1] - 4] }

        #expect(result.error <= 1e-12)
    }

    @Test("a value that affects nothing stays unchanged")
    func valueThatAffectsNothing() {
        let result = Solver.leastSquares([5, 7], steps: [1e-4, 1e-4]) { guess in [guess[0] - 2] }

        #expect(isClose(result.answer, to: [2, 7], within: 1e-6))
    }

    @Test("zero tries returns the starting guess")
    func zeroTries() {
        let result = Solver.leastSquares([5], steps: [1e-4], iterations: 0) { guess in [guess[0] - 2] }

        #expect(result.answer == [5])
        #expect(result.error == 9)
    }

    @Test("nothing to solve for returns an empty answer and the starting error")
    func nothingToSolveFor() {
        let result = Solver.leastSquares([], steps: []) { _ in [1, 2] }

        #expect(result.answer.isEmpty)
        #expect(result.error == 5)
    }

    @Test("no measurements returns the starting guess with zero error")
    func noMeasurements() {
        let result = Solver.leastSquares([1, 2], steps: [1e-4, 1e-4]) { _ in [] }

        #expect(result.answer == [1, 2])
        #expect(result.error == 0)
    }

    @Test("an unreadable first guess returns the starting guess")
    func unreadableFirstGuess() {
        let result = Solver.leastSquares([1], steps: [1e-4]) { _ in [.nan] }

        #expect(result.answer == [1])
    }

    @Test("an unreadable new guess is rejected and the best valid answer is kept")
    func unreadableNewGuess() {
        let result = Solver.leastSquares([3], steps: [1e-4]) { guess in
            guess[0] < 2.5 ? [.nan] : [guess[0] - 2]
        }

        #expect(result.answer[0] >= 2.5)
        #expect(result.answer[0] < 3)
        #expect(result.error < 1)
    }

    @Test("an adjustment size of zero returns the starting guess")
    func zeroAdjustmentSize() {
        let result = Solver.leastSquares([5], steps: [0]) { guess in [guess[0] - 2] }

        #expect(result.answer == [5])
        #expect(result.error == 9)
    }

    @Test("too few adjustment sizes returns the starting guess")
    func tooFewAdjustmentSizes() {
        let result = Solver.leastSquares([1, 2], steps: [1e-4]) { guess in [guess[0], guess[1]] }

        #expect(result.answer == [1, 2])
        #expect(result.error == 5)
    }
}

private func isClose(_ found: [Double]?, to answer: [Double], within tolerance: Double = 1e-9) -> Bool {
    guard let found, found.count == answer.count else { return false }
    return zip(found, answer).allSatisfy { abs($0 - $1) <= tolerance }
}

private func isNoAnswer(_ fit: [Double], size: Int) -> Bool {
    fit.count == size && fit.allSatisfy(\.isNaN)
}
