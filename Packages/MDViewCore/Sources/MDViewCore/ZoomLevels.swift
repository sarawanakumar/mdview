/// The zoom steps for View ▸ Zoom In / Zoom Out (spec 6.7), the same as
/// Safari's. Any current value (say, one set some other way) moves to the
/// next step in the right direction.
public enum ZoomLevels {
    public static let steps: [Double] = [0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    public static let actualSize = 1.0

    /// The next step above `zoom`, or nil at the largest.
    public static func zoomedIn(from zoom: Double) -> Double? {
        steps.first { $0 > zoom + 0.001 }
    }

    /// The next step below `zoom`, or nil at the smallest.
    public static func zoomedOut(from zoom: Double) -> Double? {
        steps.last { $0 < zoom - 0.001 }
    }

    public static func isActualSize(_ zoom: Double) -> Bool {
        abs(zoom - actualSize) < 0.001
    }
}
