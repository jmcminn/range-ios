import Foundation

// source: https://github.com/malcommac/SwiftSimplify
extension CGPoint {
    func translate(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: self.x + x, y: self.y + y)
    }

    func translateX(x: CGFloat) -> CGPoint {
        CGPoint(x: self.x + x, y: y)
    }

    func translateY(y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: self.y + y)
    }

    func invertY() -> CGPoint {
        CGPoint(x: x, y: -y)
    }

    func xAxis() -> CGPoint {
        CGPoint(x: 0, y: y)
    }

    func yAxis() -> CGPoint {
        CGPoint(x: x, y: 0)
    }

    func addTo(_ a: CGPoint) -> CGPoint {
        CGPoint(x: x + a.x, y: y + a.y)
    }

    func deltaTo(_ a: CGPoint) -> CGPoint {
        CGPoint(x: x - a.x, y: y - a.y)
    }

    func multiplyBy(_ value: CGFloat) -> CGPoint {
        CGPoint(x: x * value, y: y * value)
    }

    func divideBy(_ value: CGFloat) -> CGPoint {
        CGPoint(x: x / value, y: y / value)
    }

    func length() -> CGFloat {
        CGFloat(sqrt(CDouble(
            x * x + y * y
        )))
    }

    func normalize() -> CGPoint {
        let l = length()
        return CGPoint(x: x / l, y: y / l)
    }

    /// Returns the point with x, y coordinates rounded to nearest int
    func roundCoordinates() -> CGPoint {
        CGPoint(x: x.rounded(), y: y.rounded())
    }

    /// Returns angle between this point and given location.
    /// It gives the positive angle growing when moving counter clockwise from positive x axis
    func angle(from location: CGPoint) -> Double {
        let deltaY = location.y - y
        let deltaX = x - location.x
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        return angle
    }

    func moving(distance: Double, at angle: Double) -> CGPoint {
        .init(
            x: x + distance * __cospi(angle / 180),
            y: y - distance * __sinpi(angle / 180)
        )
    }

//    static func fromString(string: String) -> CGPoint {
//        var s = string.stringByReplacingOccurrencesOfString("{", withString: "")
//        s = s.stringByReplacingOccurrencesOfString("}", withString: "")
//        s = s.stringByReplacingOccurrencesOfString(" ", withString: "")
//
//        let x = NSString(string: s.componentsSeparatedByString(",").first! as String).doubleValue
//        let y = NSString(string: s.componentsSeparatedByString(",").last! as String).doubleValue
//
//        return CGPoint(x: CGFloat(x), y: CGFloat(y))
//    }
}
