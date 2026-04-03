import AppKit
import CoreGraphics

/// Renders the menu bar icon entirely via Core Graphics — no image assets, no SF Symbols.
///
/// Two states:
/// - badgeCount == 0: Template checkmark-in-circle icon (follows system dark/light)
/// - badgeCount > 0:  Only an orange number, no checkmark
enum StatusBarIcon {

    static func makeIcon(badgeCount: Int = 0) -> NSImage {
        if badgeCount <= 0 {
            // All done — checkmark in circle, template mode
            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size, flipped: false) { rect in
                drawCheckmarkCircle(in: rect)
                return true
            }
            image.isTemplate = true
            return image
        }

        // Has pending tasks — just the orange number, nothing else
        let countText = badgeCount > 99 ? "99+" : "\(badgeCount)"
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.systemOrange
        ]
        let countStr = NSAttributedString(string: countText, attributes: countAttrs)
        let countSize = countStr.size()

        let width = max(18, ceil(countSize.width) + 4)
        let height: CGFloat = 18
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { rect in
            let x = (rect.width - countSize.width) / 2
            let y = (rect.height - countSize.height) / 2
            countStr.draw(at: NSPoint(x: x, y: y))
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Drawing

    private static func drawCheckmarkCircle(in rect: NSRect) {
        let inset: CGFloat = 1.0
        let circleRect = rect.insetBy(dx: inset, dy: inset)

        let circlePath = NSBezierPath(ovalIn: circleRect)
        circlePath.lineWidth = 1.2
        NSColor.black.setStroke()
        circlePath.stroke()

        let checkPath = NSBezierPath()
        let cx = rect.midX
        let cy = rect.midY
        checkPath.move(to: NSPoint(x: cx - 3.5, y: cy - 0.5))
        checkPath.line(to: NSPoint(x: cx - 1.0, y: cy - 3.0))
        checkPath.line(to: NSPoint(x: cx + 4.0, y: cy + 3.0))
        checkPath.lineWidth = 1.5
        checkPath.lineCapStyle = .round
        checkPath.lineJoinStyle = .round
        NSColor.black.setStroke()
        checkPath.stroke()
    }
}
