/*
This class's only job is: solve a set of equations, or say when they have no answer.

Each row is one equation: the number in front of each unknown, then the right side.
*/
enum Solver {
    // Rows are scaled so their biggest number is 1. A leading number below this means the equations don't pin down an answer.
    private static let tooSmall = 1e-12

    static func solveLinear(_ equations: [[Double]]) -> [Double]? {
        let count = equations.count
        guard equations.allSatisfy({ $0.count == count + 1 && $0.allSatisfy(\.isFinite) }) else { return nil }

        var rows = equations.map(scaled)
        for column in 0..<count {
            guard let biggest = (column..<count).max(by: { abs(rows[$0][column]) < abs(rows[$1][column]) }),
                  abs(rows[biggest][column]) > tooSmall else { return nil }
            rows.swapAt(column, biggest)
            for other in 0..<count where other != column {
                let factor = rows[other][column] / rows[column][column]
                for i in column...count { rows[other][i] -= factor * rows[column][i] }
            }
        }
        return (0..<count).map { rows[$0][count] / rows[$0][$0] }
    }

    // The answer is c0 + c1 t + c2 t² and so on, lowest power first. No answer comes back as all NaN.
    static func polyfit(_ times: [Double], _ values: [Double], degree: Int) -> [Double] {
        guard degree >= 0 else { return [] }
        let size = degree + 1
        let noAnswer = [Double](repeating: .nan, count: size)
        guard !times.isEmpty, times.count == values.count else { return noAnswer }

        // Times far from zero make the equations too lopsided to solve, so fit around the middle time.
        let middle = times.reduce(0, +) / Double(times.count)
        var equations = [[Double]](repeating: [Double](repeating: 0, count: size + 1), count: size)
        for (time, value) in zip(times, values) {
            var powers = [Double](repeating: 1, count: size)
            for power in 1..<size { powers[power] = powers[power - 1] * (time - middle) }
            for row in 0..<size {
                for column in 0..<size { equations[row][column] += powers[row] * powers[column] }
                equations[row][size] += powers[row] * value
            }
        }
        guard let centered = solveLinear(equations) else { return noAnswer }
        return shifted(centered, back: middle)
    }

    static func polyval(_ fit: [Double], _ time: Double) -> Double {
        fit.reversed().reduce(0) { $0 * time + $1 }
    }

    private static func scaled(_ row: [Double]) -> [Double] {
        let biggest = row.dropLast().map(abs).max() ?? 0
        return biggest > 0 ? row.map { $0 / biggest } : row
    }

    private static func shifted(_ centered: [Double], back middle: Double) -> [Double] {
        var fit = [Double](repeating: 0, count: centered.count)
        for number in centered.reversed() {
            var next = fit.map { -middle * $0 }
            for power in 1..<fit.count { next[power] += fit[power - 1] }
            next[0] += number
            fit = next
        }
        return fit
    }
}
