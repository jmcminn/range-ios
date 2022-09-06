import Foundation
import UIKit

enum PanDirection {
    case vertical
    case horizontal
}

// TODO: 227 for interactive transitioning
/// Subclass of UIPanGestureRecognizer that only recognizes pan in given direction (horizontal or vertical)
class PanDirectionGestureRecognizer: UIPanGestureRecognizer {
    let direction: PanDirection

    init(direction: PanDirection, target: AnyObject, action: Selector) {
        self.direction = direction
        super.init(target: target, action: action)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        if state == .began {
            let vel = velocity(in: view)
            switch direction {
            case .horizontal where abs(vel.y) > abs(vel.x):
                state = .cancelled
            case .vertical where abs(vel.x) > abs(vel.y):
                state = .cancelled
            default:
                break
            }
        }
    }
}
