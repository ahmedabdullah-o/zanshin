import AppKit

/// Hand-drawn template glyphs for the menu bar and brand marks.
/// Everything is vector (redrawn on demand), monochrome via alpha,
/// and marked as template so macOS tints it correctly.
enum ZanshinGlyph {

    /// Katana, diagonal, tip to the upper right.
    static func katana(size: CGFloat = 16) -> NSImage {
        image(size: size) { s in
            let dir = CGVector(dx: cos(Double.pi / 4), dy: sin(Double.pi / 4))
            let perp = CGVector(dx: -dir.dy, dy: dir.dx)
            let c = CGPoint(x: s / 2, y: s / 2)

            func along(_ d: CGFloat) -> CGPoint {
                CGPoint(x: c.x + dir.dx * d * s, y: c.y + dir.dy * d * s)
            }
            func off(_ p: CGPoint, _ d: CGFloat) -> CGPoint {
                CGPoint(x: p.x + perp.dx * d * s, y: p.y + perp.dy * d * s)
            }

            let handleStart = along(-0.38)
            let tsuba = along(-0.27)
            let bladeStart = along(-0.25)
            let tipBase = along(0.30)
            let tip = along(0.39)
            let bladeHalf = 0.048
            let taper = 0.034

            // Blade with angled kissaki.
            let blade = NSBezierPath()
            blade.move(to: off(bladeStart, bladeHalf))
            blade.line(to: off(tipBase, taper))
            blade.curve(
                to: tip,
                controlPoint1: off(along(0.36), 0.030),
                controlPoint2: off(tip, bladeHalf * 0.5)
            )
            blade.line(to: off(tipBase, -taper))
            blade.line(to: off(bladeStart, -bladeHalf))
            blade.close()
            blade.fill()

            // Tsuba guard.
            let guardPath = NSBezierPath()
            guardPath.move(to: off(tsuba, 0.085))
            guardPath.line(to: off(along(-0.235), 0.085))
            guardPath.line(to: off(along(-0.235), -0.085))
            guardPath.line(to: off(tsuba, -0.085))
            guardPath.close()
            guardPath.fill()

            // Tsuka handle.
            let handle = NSBezierPath()
            let handleHalf = 0.058
            handle.move(to: off(handleStart, handleHalf))
            handle.line(to: off(tsuba, handleHalf))
            handle.line(to: off(tsuba, -handleHalf))
            handle.line(to: off(handleStart, -handleHalf))
            handle.close()
            handle.fill()
        }
    }

    /// Ensō — an open brush circle, opening to the upper right.
    static func enso(size: CGFloat = 16) -> NSImage {
        image(size: size) { s in
            let path = NSBezierPath()
            path.lineWidth = s * 0.14
            path.lineCapStyle = .round
            path.appendArc(
                withCenter: CGPoint(x: s / 2, y: s / 2),
                radius: s * 0.34,
                startAngle: 60,
                endAngle: 60 - 322,
                clockwise: true
            )
            path.stroke()
        }
    }

    /// Tea cup for break sessions.
    static func tea(size: CGFloat = 16) -> NSImage {
        image(size: size) { s in
            let body = NSBezierPath(roundedRect: NSRect(
                x: s * 0.14, y: s * 0.22, width: s * 0.52, height: s * 0.40
            ), xRadius: s * 0.08, yRadius: s * 0.08)
            body.fill()

            let handle = NSBezierPath()
            handle.lineWidth = s * 0.09
            handle.appendArc(
                withCenter: CGPoint(x: s * 0.70, y: s * 0.42),
                radius: s * 0.14,
                startAngle: 70,
                endAngle: -70,
                clockwise: true
            )
            handle.stroke()

            // Saucer line beneath.
            let saucer = NSBezierPath()
            saucer.lineWidth = s * 0.08
            saucer.lineCapStyle = .round
            saucer.move(to: CGPoint(x: s * 0.16, y: s * 0.10))
            saucer.line(to: CGPoint(x: s * 0.64, y: s * 0.10))
            saucer.stroke()
        }
    }

    /// Hanko seal — solid rounded square with a circular mon knocked out.
    static func seal(size: CGFloat = 16) -> NSImage {
        image(size: size) { s in
            let outer = NSBezierPath(
                roundedRect: NSRect(x: s * 0.12, y: s * 0.12, width: s * 0.76, height: s * 0.76),
                xRadius: s * 0.16, yRadius: s * 0.16
            )
            outer.append(NSBezierPath(
                ovalIn: NSRect(x: s * 0.30, y: s * 0.30, width: s * 0.40, height: s * 0.40)
            ))
            outer.windingRule = .evenOdd
            outer.fill()
        }
    }

    // MARK: Plumbing

    private static func image(size: CGFloat, draw: @escaping (CGFloat) -> Void) -> NSImage {
        let nsSize = NSSize(width: size, height: size)
        let img = NSImage(size: nsSize, flipped: false) { rect in
            NSGraphicsContext.current?.cgContext.translateBy(
                x: rect.minX, y: rect.minY
            )
            draw(rect.width)
            return true
        }
        img.isTemplate = true
        return img
    }
}
