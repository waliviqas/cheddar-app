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

    // Keeps adjusting the starting guess until its misses stop shrinking. Each miss is how far one measurement is from the guess.
    static func leastSquares(_ start: [Double], steps: [Double], iterations: Int = 100,
                             _ misses: ([Double]) -> [Double]) -> (answer: [Double], error: Double) {
        var answer = start
        var current = misses(answer)
        var error = squaredTotal(current)
        guard steps.count == start.count else { return (answer, error) }

        // Higher caution means smaller adjustments.
        var caution = 1e-3
        for _ in 0..<iterations {
            let slopes = answer.indices.map { index in
                var nudged = answer
                nudged[index] += steps[index]
                return zip(misses(nudged), current).map { ($0 - $1) / steps[index] }
            }
            var improved = false
            for _ in 0..<10 where !improved {
                if let change = adjustment(slopes, current, caution: caution) {
                    let trial = zip(answer, change).map { $0 + $1 }
                    let trialMisses = misses(trial)
                    let trialError = squaredTotal(trialMisses)
                    if trialError < error {
                        let gain = (error - trialError) / error
                        answer = trial
                        current = trialMisses
                        error = trialError
                        caution = max(caution / 10, 1e-12)
                        if gain < 1e-12 { return (answer, error) }
                        improved = true
                        continue
                    }
                }
                caution *= 10
            }
            if !improved { break }
        }
        return (answer, error)
    }

    private static func adjustment(_ slopes: [[Double]], _ misses: [Double], caution: Double) -> [Double]? {
        let equations = slopes.indices.map { row -> [Double] in
            var equation = slopes.indices.map { dot(slopes[row], slopes[$0]) }
            // The tiny extra stops a value that affects nothing from blocking the solve.
            equation[row] = equation[row] * (1 + caution) + 1e-12
            return equation + [-dot(slopes[row], misses)]
        }
        return solveLinear(equations)
    }

    private static func dot(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    private static func squaredTotal(_ misses: [Double]) -> Double {
        dot(misses, misses)
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
