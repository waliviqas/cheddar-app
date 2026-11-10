/*
This class's only job is: hold the camera's lens numbers so CameraPose can use them.
*/
public struct LensInfo {
    public let width: Double     // picture size in pixels
    public let height: Double
    public let centerX: Double   // the lens's center, in pixels
    public let centerY: Double
    public let zoom: Double      // how zoomed in, in pixels

    public init(width: Double, height: Double, centerX: Double, centerY: Double, zoom: Double) {
        self.width = width
        self.height = height
        self.centerX = centerX
        self.centerY = centerY
        self.zoom = zoom
    }
}
