/*
This class's only job is: hold one video frame's colors and say what color is at a spot.

Row 0 is the top of the picture. Every pixel is 3 numbers in a row: red, green, blue.
*/
struct Picture {
    let width: Int, height: Int
    let rgb: [UInt8]

    func color(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int)? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let i = (y * width + x) * 3
        return (Int(rgb[i]), Int(rgb[i + 1]), Int(rgb[i + 2]))
    }
}
