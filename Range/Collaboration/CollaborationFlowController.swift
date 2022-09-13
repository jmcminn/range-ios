import Foundation
import OSLog
import UIKit

/// Manages displaying collaboration window
class CollaborationFlowController {
    unowned let model: ProjectModel
    unowned let imageCaches: ImageCaches
    unowned let canvasContainer: CanvasContainerViewController

    /// callback to notify that collaboration window is closing
    var onCollaborationClose: (() -> Void)?

    /// Currently shown collaboration
    var collaboration: Collaboration?
    /// currently shown collaboration window
    var collaborationVC: CollaborationViewController?
    /// the view covering the collaboration window in full screen mode (when the collaboration window card is in max position)
    var collaborationHeaderCoverVC: CollaborationHeaderCoverViewController?

    ///
    /// - Parameters:
    ///     - model: - the project model
    ///     - images: - access to images
    ///     - canvas: - the flow will operate on this canvas
    init(model: ProjectModel, imageCaches: ImageCaches, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.imageCaches = imageCaches
        self.canvasContainer = canvasContainer
    }

    /// Finds the first collaboration for this geometry and show its window
    func showCollaborationWindow(forGeometry geometryId: String, animated: Bool) {
        if let geometry = model.mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId),
           let feature = geometry.features.first,
           let collaboration = feature.collaborations.first
        {
            self.collaboration = collaboration
            let collaborationVC = CollaborationViewController(imageCaches: imageCaches, collaboration: collaboration)
            collaborationVC.onClose = { [weak self] in
                self?.onCollaborationClose?()
            }

            canvasContainer.installCard(
                cardViewController: collaborationVC,
                inView: canvasContainer.controls,
                cardConfig: CardConfiguration(initialCardPosition: .medium, allowsFullScreen: true)
            )
            collaborationVC.cardDragging?.delegate = self

            // check if already showing, if so then ignore animated and replace instantly
            if self.collaborationVC != nil {
                self.collaborationVC?.cardDragging?.delegate = nil
                hideCollaborationWindow(animated: false)
                setCollaborationHeaderCoverHidden(true, animated: false)
                collaborationVC.showCard(animated: false)
            } else {
                collaborationVC.showCard(animated: animated)
            }
            addCollaborationHeaderCover()
            self.collaborationVC = collaborationVC
        } else {
            Logger.model.warning("""
                Trying to present collaboration window for geometry
                \(geometryId, privacy: .public) with no collaboration
            """)
        }
    }

    /// Hide the currently shown collaboration window (and the header cover)
    func hideCollaborationWindow(animated: Bool) {
        if let collaborationVC = collaborationVC {
            collaborationVC.cardDragging?.delegate = nil
            collaborationVC.hideCard(animated: animated) {
                self.canvasContainer.removeCard(cardViewController: collaborationVC)
            }
            self.collaborationVC = nil
        }
        setCollaborationHeaderCoverHidden(true, animated: animated)
        removeCollaborationHeaderCover()
    }

    /// Adds the top cover for collaboration window. Initially with alpha = 0
    private func addCollaborationHeaderCover() {
        guard let collaboration = collaboration else { return }
        if let collaborationHeaderCoverVC = collaborationHeaderCoverVC,
           collaborationHeaderCoverVC.collaboration.id == collaboration.id
        {
            // already added
            return
        }
        let collaborationHeaderCoverVC = CollaborationHeaderCoverViewController(collaboration: collaboration)
        collaborationHeaderCoverVC.onClose = { [weak self] in
            self?.onCollaborationClose?()
        }
        canvasContainer.add(childController: collaborationHeaderCoverVC, toView: canvasContainer.controls)
        collaborationHeaderCoverVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }
        collaborationHeaderCoverVC.view.alpha = 0
        self.collaborationHeaderCoverVC = collaborationHeaderCoverVC
    }

    private func removeCollaborationHeaderCover() {
        guard let collaborationHeaderCoverVC = collaborationHeaderCoverVC else { return }
        canvasContainer.remove(childController: collaborationHeaderCoverVC)
        self.collaborationHeaderCoverVC = nil
    }

    // TODO: 287: show FABs (floating action button)
    /// hides/shows the view controller covering the top of of the screen
    private func setCollaborationHeaderCoverHidden(_ hidden: Bool, animated: Bool) {
        if let collaborationHeaderCoverVC = collaborationHeaderCoverVC {
            if animated {
                UIView.animate(withDuration: 0.2) {
                    collaborationHeaderCoverVC.view.alpha = hidden ? 0 : 1
                }

            } else {
                collaborationHeaderCoverVC.view.alpha = hidden ? 0 : 1
            }
        }
    }
}

// MARK: Card dragging delegate

extension CollaborationFlowController: CardDraggingDelegate {
    // hide collaboration when the window is minimized
    func cardWillChangePosition(_ position: CardPosition) {
        if position == .min {
            onCollaborationClose?()
        }
        // only show the header cover in .max position
        setCollaborationHeaderCoverHidden(position != .max, animated: true)
    }

    /// Animate the collaboration header cover alpha as user is dragging the collaboration window card
    func cardHeightUpdated(_ height: CGFloat) {
        // show/hide the header cover
        guard let collaborationVC = collaborationVC,
              let cardDragging = collaborationVC.cardDragging,
              let collaborationHeaderCoverVC = collaborationHeaderCoverVC else { return }
        // HACK: the height reported by dragging includes the safeAreaInsets while the height
        // requested by card presentable (collaborationVC) does not...
        let realHeight = height - cardDragging.containerView.safeAreaInsets.bottom
        let fullHeight = collaborationVC.height(forContainer: cardDragging.containerView, cardPosition: .max)
        // alpha is 1 when full height - 100 and then drops to 0 on a distance of 20 points
        // the 100 and 20 are arbitrary numbers selected to make the alpha transition fast (20)
        // and to start it early (100 + 20 points before height reaches the full height)
        let alpha = 1.0 - (fullHeight - realHeight - 100) / 20
        collaborationHeaderCoverVC.view.alpha = max(0, min(1, alpha))
    }
}
