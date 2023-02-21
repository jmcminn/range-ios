import Foundation
import UIKit

// Good set of articles on view controller transitions: https://danielgauthier.me/2020/02/19/indie-4.html
// although this was still more based on: https://github.com/zvonicek/ImageSlideshow/blob/master/ImageSlideshow/Classes/Core/ZoomAnimatedTransitioning.swift

/// Support transitioning from a view controller with photo to FullscreenImageGalleryViewController
class FullscreenImageGalleryTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    weak var galleryVC: ImageGalleryViewController<MediaKey>?
    weak var fullscreenGalleryVC: FullscreenImageGalleryViewController?
    weak var interactivePresentation: UIViewControllerInteractiveTransitioning?
    fileprivate var interactiveDismissal: UIPercentDrivenInteractiveTransition?

    /// Init the transitioning delegate to transition from ImageGalleryViewController
    /// - parameter galleryVC: gallery from which to transition
    /// - parameter fullscreenGalleryVC: show this fullscreen gallery view controller
    /// - parameter interactivePresentation: optional controller for interactive presentation, if not provided then it's non interactive
    public init(
        fromGallery galleryVC: ImageGalleryViewController<MediaKey>,
        toFullscreenGallery fullscreenGalleryVC: FullscreenImageGalleryViewController,
        interactivePresentation: UIViewControllerInteractiveTransitioning?
    ) {
        self.galleryVC = galleryVC
        self.fullscreenGalleryVC = fullscreenGalleryVC
        self.interactivePresentation = interactivePresentation
        super.init()

        let panGestureRecognizer = PanDirectionGestureRecognizer(
            direction: .vertical,
            target: self,
            action: #selector(handlePanGesture(_:))
        )
        panGestureRecognizer.cancelsTouchesInView = false
        fullscreenGalleryVC.scrollView.addGestureRecognizer(panGestureRecognizer)
    }

    /// when user drags the photo up initiate the interactionController and start fullscreenGalleryVC dismissal.
    /// UIPercentDrivenInteractiveTransition will work together with `FullscreenImageGalleryDismissalAnimatedTransitioning` and
    /// will set the animation progress to whatever is the calculated percentage of gesture (100% set to translation = 200 points - this
    /// is arbitrary and may be in future calculated from the real distance between the full screen image and the target frame in details screen)
    @objc
    func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard let fullscreenGalleryVC = fullscreenGalleryVC else { return }
        guard let galleryVC = galleryVC else { return }

        // up only
        let percent = min(max(-gesture.translation(in: gesture.view!).y / 200.0, 0.0), 1.0)

        if gesture.state == .began {
            // before triggering dismissal let's first update the galleryVC page so it matches
            // the fullscreen one (otherwise we would possibly animate a photo onto a different photo)
            galleryVC.setCurrentPage(fullscreenGalleryVC.currentPage)
            interactiveDismissal = UIPercentDrivenInteractiveTransition()
            fullscreenGalleryVC.dismiss(animated: true)
        } else if gesture.state == .changed {
            interactiveDismissal?.update(percent)
        } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            let velocity = gesture.velocity(in: view)
            // up only
            if velocity.y < -500 {
                interactiveDismissal?.finish()
            } else if percent > 0.5 {
                interactiveDismissal?.finish()
            } else {
                interactiveDismissal?.cancel()
            }
            interactiveDismissal = nil
        }
    }

    func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        guard let referenceImageView = galleryVC?.imageViewForCurrentPage else {
            return nil
        }
        return FullscreenImageGalleryPresentationAnimatedTransitioning(referenceImageView: referenceImageView)
    }

    func interactionControllerForPresentation(using _: UIViewControllerAnimatedTransitioning)
        -> UIViewControllerInteractiveTransitioning?
    {
        interactivePresentation
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let referenceImageView = fullscreenGalleryVC?.imageViewForCurrentPage,
              let referenceImage = referenceImageView.image,
              let targetView = galleryVC?.viewForCurrentPage
        else {
            // if we are not using the fullscreen transition for dismissal then reset the "from" vc
            // alpha to 1 so it's visible again (otherwise the alpha is animated from 0 to 1 in
            // FullscreenImageGalleryDismissalAnimatedTransitioning
            dismissed.presentingViewController?.view.alpha = 1
            return nil
        }

        let imageHeight2Width = referenceImage.size.height / referenceImage.size.width
        let targetFrame = targetView.imageViewFrame(forImageHeight2Width: imageHeight2Width)

        return FullscreenImageGalleryDismissalAnimatedTransitioning(
            referenceImageView: referenceImageView,
            targetFrame: targetFrame,
            inView: targetView
        )
    }

    open func interactionControllerForDismissal(using _: UIViewControllerAnimatedTransitioning)
        -> UIViewControllerInteractiveTransitioning?
    {
        interactiveDismissal
    }
}

/// Zooming in to FullscreenImageGalleryViewController
class FullscreenImageGalleryPresentationAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    private let referenceImageView: UIImageView

    private var animatorForCurrentTransition: UIViewImplicitlyAnimating?

    /// - parameter referenceImageView the view that will be animated to full screen
    init(referenceImageView: UIImageView) {
        self.referenceImageView = referenceImageView
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    /// animate from a view controller with referenceImage to FullscreenImageGalleryViewController by animating fromVC.alpha to 0,
    /// animating toVC to 1 and animating the size/position of a photo (for this we create a transition view with same image so the
    /// original and target image/gallery stay untouched)
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning)
        -> UIViewImplicitlyAnimating
    {
        // Reuse animator for subsequent calls to `animateTransition` otherwise the interactive transition doesn't work
        if let animatorForCurrentSession = animatorForCurrentTransition {
            return animatorForCurrentSession
        }

        let containerView = transitionContext.containerView
        let fromVC = transitionContext.viewController(forKey: .from)!
        guard let fullscreenVC = transitionContext.viewController(forKey: .to) as? FullscreenImageGalleryViewController
        else {
            fatalError("Transition not used with FullscreenImageGalleryViewController")
        }

        fullscreenVC.view.frame = transitionContext.finalFrame(for: fullscreenVC)
        fullscreenVC.view.alpha = 0
        // this won't animate but will change to 1 on completion, not to interfere with transition
        // view animation
        fullscreenVC.scrollView.alpha = 0
        let fullscreenBackgroundColor = fullscreenVC.view.backgroundColor
        // fullscreen image gallery is rendered on top of transition view so it needs to be
        // transparent for the time of transition
        fullscreenVC.view.backgroundColor = .clear

        // hide immediately as we will move the transition view (with same photo) and they
        // cannot be both visible at the same time
        referenceImageView.alpha = 0

        let transitionView = UIImageView(image: referenceImageView.image)
        transitionView.contentMode = .scaleAspectFit
        transitionView.layer.cornerRadius = referenceImageView.layer.cornerRadius
        transitionView.clipsToBounds = true
        transitionView.frame = containerView.convert(referenceImageView.bounds, from: referenceImageView)
        containerView.addSubview(transitionView)

        containerView.addSubview(fullscreenVC.view)

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            dampingRatio: 1.0
        ) {
            fromVC.view.alpha = 0
            fullscreenVC.view.alpha = 1
            transitionView.frame = fullscreenVC.view.frame
            transitionView.center = fullscreenVC.view.center
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            self.referenceImageView.alpha = 1
            fullscreenVC.scrollView.alpha = 1
            fullscreenVC.view.backgroundColor = fullscreenBackgroundColor
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        animatorForCurrentTransition = animator

        return animator
    }
}

/// Zoom out from the FullscreenImageGalleryViewController
class FullscreenImageGalleryDismissalAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    private let referenceImageView: UIImageView
    private let targetFrame: CGRect
    private let targetView: UIView

    private var animatorForCurrentTransition: UIViewImplicitlyAnimating?

    /// - parameter referenceImageView the view that will be animated to target frame
    /// - parameter targetFrame target frame for the animated view
    /// - parameter targetView target view to transition to
    init(referenceImageView: UIImageView, targetFrame: CGRect, inView targetView: UIView) {
        self.referenceImageView = referenceImageView
        self.targetFrame = targetFrame
        self.targetView = targetView
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    /// animate from a FullscreenImageGalleryViewController to a view controller with targetView and targetFrame for the image
    /// by animating fromVC.alpha to 0, animating toVC to 1 and animating the size/position of a photo (for this we create a transition
    /// view with same image so the original and target image/gallery stay untouched)
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning)
        -> UIViewImplicitlyAnimating
    {
        // Reuse animator for subsequent calls to `animateTransition` otherwise the interactive transition doesn't work
        if let animatorForCurrentSession = animatorForCurrentTransition {
            return animatorForCurrentSession
        }

        let containerView = transitionContext.containerView
        guard let fullscreenVC = transitionContext
            .viewController(forKey: .from) as? FullscreenImageGalleryViewController
        else {
            fatalError("Transition not used with FullscreenImageGalleryViewController")
        }
        let toVC = transitionContext.viewController(forKey: .to)!
        let targetFrame = containerView.convert(targetFrame, from: targetView)

        toVC.view.alpha = 0

        // hide immediately as we will move the transition view (with same photo) and they
        // cannot be both visible at the same time
        referenceImageView.alpha = 0
        // hide target view for the time of transition
        targetView.alpha = 0

        let transitionView = UIImageView(image: referenceImageView.image)
        transitionView.contentMode = .scaleAspectFit
        transitionView.clipsToBounds = true
        transitionView.frame = containerView.convert(referenceImageView.bounds, from: referenceImageView)
        // so the buttons of fullscreen vc are on top of the transition view
        containerView.insertSubview(transitionView, belowSubview: fullscreenVC.view)

        let fullscreenBackgroundColor = fullscreenVC.view.backgroundColor
        // fullscreen vc rendered on top of transition view so it needs to be transparent for the time
        // of transition
        fullscreenVC.view.backgroundColor = .clear

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            dampingRatio: 1.0
        ) {
            fullscreenVC.view.alpha = 0
            toVC.view.alpha = 1
            transitionView.layer.cornerRadius = 13
            transitionView.frame = targetFrame
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            fullscreenVC.view.alpha = 1
            self.targetView.alpha = 1
            self.referenceImageView.alpha = 1
            fullscreenVC.view.backgroundColor = fullscreenBackgroundColor
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animatorForCurrentTransition = animator

        return animator
    }
}
