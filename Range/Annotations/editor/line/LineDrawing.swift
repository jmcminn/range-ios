import Foundation
import UIKit

/// Handles the initial line "drawing" - it's a wrapper for pan gesture recognizer. The beginning of pan marks the start point of the line,
/// the endpoint is updated during the gesture.
class LineDrawing {
    private(set) var gestureRecognizer: UIGestureRecognizer?

    /// The annotation being currently drawn
    var annotationViewModel: LineAnnotationViewModel?

    var startPoint: CGPoint?

    var onDrawingBegan: (() -> Void)?
    var onAnnotationCreated: ((CGPoint, CGPoint) -> LineAnnotationViewModel?)?
    var onDrawingEnded: (() -> Void)?

    init() {
        gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
    }

    @objc private func panGesture(gesture: UIGestureRecognizer) {
        // We round the coordinates, there's no point in dealing with non int coordinates
        let location = gesture.location(in: gesture.view).roundCoordinates()

        if gesture.state == .began {
            // do not create the annotation yet, we just have 1 point so it doesn't make sense to
            // draw the line with startPoint = endPoint
            startPoint = location
            onDrawingBegan?()
        }

        if gesture.state == .changed {
            if let annotationViewModel {
                // update the endpoint
                annotationViewModel.setEndPoint(location)
            } else {
                // create the line with the new position being the end point and the start point defined
                // when the gesture began
                guard let startPoint = startPoint else { return }
                annotationViewModel = onAnnotationCreated?(startPoint, location)
            }
        }

        if gesture.state == .ended {
            // reset the internal state, so it can handle the next annotation drawing
            startPoint = nil
            annotationViewModel = nil
            onDrawingEnded?()
        }
    }
}
