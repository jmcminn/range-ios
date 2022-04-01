import UIKit

protocol PresentationContainerViewDelegate: AnyObject {
    func view(_ view: PresentationContainerView, shouldPassthroughTouchAt point: CGPoint) -> Bool
    func view(_ view: PresentationContainerView, forTouchAt point: CGPoint) -> UIView?
}

/// A view which removes itself from the responder chain and asks its delegate for a view that should handle the touch
class PresentationContainerView: UIView {
    weak var touchDelegate: PresentationContainerViewDelegate?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let touchDelegate = touchDelegate,
            touchDelegate.view(self, shouldPassthroughTouchAt: point),
            let viewForTouch = touchDelegate.view(self, forTouchAt: point) else {
                return super.hitTest(point, with: event)
        }

        let pointInView = viewForTouch.convert(point, from: self)
        return viewForTouch.hitTest(pointInView, with: event)
    }
}
