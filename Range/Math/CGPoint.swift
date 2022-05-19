import UIKit

func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
    (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
}
