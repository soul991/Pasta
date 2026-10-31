import Foundation

/// Mathematical utility for calculating the largest centered crop rectangle of a target aspect ratio
/// fitting within container dimensions, rounded to even pixel values for video codec compatibility.
public enum CropCalculator {
    public static func computeCrop(
        containerWidth: Int,
        containerHeight: Int,
        ratioWidth: Int,
        ratioHeight: Int
    ) -> (x: Int, y: Int, width: Int, height: Int) {
        guard containerWidth > 0, containerHeight > 0, ratioWidth > 0, ratioHeight > 0 else {
            return (0, 0, 0, 0)
        }

        let targetRatio = Double(ratioWidth) / Double(ratioHeight)
        let containerRatio = Double(containerWidth) / Double(containerHeight)

        var w: Int
        var h: Int

        if containerRatio > targetRatio {
            // Container is wider than target ratio: container height is the bounding constraint
            let rawH = containerHeight
            let rawW = Double(rawH) * targetRatio
            h = makeEvenFloor(rawH)
            w = roundToEven(rawW)
            if w > containerWidth {
                w = makeEvenFloor(containerWidth)
                h = roundToEven(Double(w) / targetRatio)
            }
        } else {
            // Container is taller than or equal to target ratio: container width is the bounding constraint
            let rawW = containerWidth
            let rawH = Double(rawW) / targetRatio
            w = makeEvenFloor(rawW)
            h = roundToEven(rawH)
            if h > containerHeight {
                h = makeEvenFloor(containerHeight)
                w = roundToEven(Double(h) * targetRatio)
            }
        }

        if w > containerWidth { w = makeEvenFloor(containerWidth) }
        if h > containerHeight { h = makeEvenFloor(containerHeight) }

        let x = max(0, (containerWidth - w) / 2)
        let y = max(0, (containerHeight - h) / 2)
        return (x: x, y: y, width: w, height: h)
    }

    public static func makeEvenFloor(_ val: Int) -> Int {
        return (val % 2 == 0) ? val : val - 1
    }

    public static func roundToEven(_ val: Double) -> Int {
        let rounded = Int(round(val))
        if rounded % 2 == 0 {
            return rounded
        }
        let lower = rounded - 1
        let upper = rounded + 1
        return (abs(Double(lower) - val) < abs(Double(upper) - val)) ? lower : upper
    }
}
