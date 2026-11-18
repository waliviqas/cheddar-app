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
}

private func isClose(_ found: [Double]?, to answer: [Double]) -> Bool {
    guard let found, found.count == answer.count else { return false }
    return zip(found, answer).allSatisfy { abs($0 - $1) <= 1e-9 }
}
