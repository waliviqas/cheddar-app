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

    private static func scaled(_ row: [Double]) -> [Double] {
        let biggest = row.dropLast().map(abs).max() ?? 0
        return biggest > 0 ? row.map { $0 / biggest } : row
    }
}
