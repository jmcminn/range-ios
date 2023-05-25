import Foundation

// source: https://github.com/malcommac/SwiftSimplify
extension CGPoint {
    func translate(x: CGFloat, _ y: CGFloat) -> CGPoint {
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
