import Foundation
import CoreGraphics

public struct WheelGeometry {
    // Panel Dimensions calibrated so all 8 nodes, maximum 1.06 scale hover,
    // 18pt accent glow, 10pt shadow, and controls fit with >= 8pt margin.
    public static let panelWidth: CGFloat = 520.0
    public static let panelHeight: CGFloat = 560.0
    public static let wheelCenterX: CGFloat = 260.0
    public static let wheelCenterY: CGFloat = 310.0

    // Radial layout metrics
    public static let orbitRadius: CGFloat = 148.0
    public static let nodeDefaultWidth: CGFloat = 90.0
    public static let nodeDefaultHeight: CGFloat = 38.0
    public static let maxHoverScale: CGFloat = 1.06
    public static let maxGlowRadius: CGFloat = 18.0
    public static let maxShadowRadius: CGFloat = 10.0
    public static let minMargin: CGFloat = 8.0

    /// Computes the center position of a node at a given slot index (0 = top, 2 = right, 4 = bottom, 6 = left)
    public static func nodeCenter(index: Int, totalSlots: Int = 8) -> CGPoint {
        let angle = (-CGFloat.pi / 2.0) + (CGFloat(index) * (2.0 * CGFloat.pi / CGFloat(totalSlots)))
        let x = wheelCenterX + (orbitRadius * cos(angle))
        let y = wheelCenterY + (orbitRadius * sin(angle))
        return CGPoint(x: x, y: y)
    }

    /// Computes the bounding box of a node including its scale, glow, and shadow radii
    public static func nodeExtents(
        index: Int,
        totalSlots: Int = 8,
        nodeWidth: CGFloat = nodeDefaultWidth,
        nodeHeight: CGFloat = nodeDefaultHeight,
        scale: CGFloat = maxHoverScale,
        glowRadius: CGFloat = maxGlowRadius,
        shadowRadius: CGFloat = maxShadowRadius
    ) -> CGRect {
        let center = nodeCenter(index: index, totalSlots: totalSlots)
        let scaledW = nodeWidth * scale
        let scaledH = nodeHeight * scale
        let totalOverflow = glowRadius + shadowRadius

        let minX = center.x - (scaledW / 2.0) - totalOverflow
        let maxX = center.x + (scaledW / 2.0) + totalOverflow
        let minY = center.y - (scaledH / 2.0) - totalOverflow
        let maxY = center.y + (scaledH / 2.0) + totalOverflow

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Computes panel origin clamped within the screen's visible frame
    public static func computePanelOrigin(
        cursorPoint: CGPoint,
        panelSize: CGSize = CGSize(width: panelWidth, height: panelHeight),
        centerOffset: CGPoint = CGPoint(x: wheelCenterX, y: wheelCenterY),
        visibleFrame: CGRect,
        edgeMargin: CGFloat = 10.0
    ) -> CGPoint {
        var origin = CGPoint(x: cursorPoint.x - centerOffset.x, y: cursorPoint.y - centerOffset.y)

        let minX = visibleFrame.minX + edgeMargin
        let maxX = visibleFrame.maxX - panelSize.width - edgeMargin
        let minY = visibleFrame.minY + edgeMargin
        let maxY = visibleFrame.maxY - panelSize.height - edgeMargin

        if maxX >= minX {
            origin.x = max(minX, min(origin.x, maxX))
        } else {
            origin.x = minX
        }

        if maxY >= minY {
            origin.y = max(minY, min(origin.y, maxY))
        } else {
            origin.y = minY
        }

        return origin
    }

    /// Determines if bottom of the wheel panel is cramped near screen bottom or dock
    public static func isBottomCramped(panelOrigin: CGPoint, visibleFrame: CGRect, threshold: CGFloat = 60.0) -> Bool {
        return panelOrigin.y <= (visibleFrame.minY + threshold)
    }
}
