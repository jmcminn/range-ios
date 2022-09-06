import Foundation
import UIKit

// Good set of articles on view controller transitions: https://danielgauthier.me/2020/02/19/indie-4.html
// although this was still more based on: https://github.com/zvonicek/ImageSlideshow/blob/master/ImageSlideshow/Classes/Core/ZoomAnimatedTransitioning.swift

/// Support transitioning from a view controller with photo to full screen PhotosReviewViewController
class PhotosReviewTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    weak var galleryVC: ImageGalleryViewController<String>?
    weak var photosReviewVC: PhotosReviewViewController?
    fileprivate var interactionController: UIPercentDrivenInteractiveTransition?

    /// Init the transitioning delegate to transition from ImageGalleryViewController
    /// - parameter galleryVC: gallery from which to transition
    /// - parameter photosReviewVC: show this photos review view controller in full screen
    public init(
        fromGallery galleryVC: ImageGalleryViewController<String>,
        toPhotosReview photosReviewVC: PhotosReviewViewController
    ) {
        self.galleryVC = galleryVC
        self.photosReviewVC = photosReviewVC
        super.init()

        let panGestureRecognizer = PanDirectionGestureRecognizer(
            direction: .vertical,
            target: self,
            action: #selector(handlePanGesture(_:))
        )
        panGestureRecognizer.cancelsTouchesInView = false
        photosReviewVC.scrollView.addGestureRecognizer(panGestureRecognizer)
    }

    /// when user drags the photo up initiate the interactionController and start photosReviewVC dismissal.
    /// UIPercentDrivenInteractiveTransition will work together with `PhotosReviewDismissalAnimatedTransitioning` and
    /// will set the animation progress to whatever is the calculated percentage of gesture (100% set to translation = 200 points - this
    /// is arbitrary and may be in future calculated from the real distance between the full screen image and the target frame in details screen)
    @objc
    func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard let photosReviewVC = photosReviewVC else { return }
        guard let galleryVC = galleryVC else { return }

        // up only
        let percent = min(max(-gesture.translation(in: gesture.view!).y / 200.0, 0.0), 1.0)

        if gesture.state == .began {
            // before triggering dismissal let's first update the galleryVC page so it matches
            // the photosReview one (otherwise we would possibly animate a photo onto a different photo)
            galleryVC.setCurrentPage(photosReviewVC.currentPage)
            interactionController = UIPercentDrivenInteractiveTransition()
            photosReviewVC.dismiss(animated: true)
        } else if gesture.state == .changed {
            interactionController?.update(percent)
        } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            let velocity = gesture.velocity(in: view)
            // up only
            if velocity.y < -500 {
                interactionController?.finish()
            } else if percent > 0.5 {
                interactionController?.finish()
            } else {
                interactionController?.cancel()
            }
            interactionController = nil
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
        return PhotosReviewPresentationAnimatedTransitioning(referenceImageView: referenceImageView)
    }

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let referenceImageView = photosReviewVC?.imageViewForCurrentPage else { return nil }
        guard let referenceImage = referenceImageView.image else { return nil }
        let imageHeight2Width = referenceImage.size.height / referenceImage.size.width

        guard let targetView = galleryVC?.viewForCurrentPage else { return nil }
        let targetFrame = targetView.imageViewFrame(forImageHeight2Width: imageHeight2Width)

        return PhotosReviewDismissalAnimatedTransitioning(
            referenceImageView: referenceImageView,
            targetFrame: targetFrame,
            inView: targetView
        )
    }

    open func interactionControllerForDismissal(using _: UIViewControllerAnimatedTransitioning)
        -> UIViewControllerInteractiveTransitioning?
    {
        interactionController
    }
}

/// Zooming in to PhotosReviewViewController
class PhotosReviewPresentationAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    private let referenceImageView: UIImageView

    /// - parameter referenceImageView the view that will be animated to full screen
    init(referenceImageView: UIImageView) {
        self.referenceImageView = referenceImageView
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }

    /// animate from a view controller with referenceImage to PhotosReviewViewController by animating fromVC.alpha to 0,
    /// animating toVC to 1 and animating the size/position of a photo (for this we create a transition view with same image so the
    /// original and target image/gallery stay untouched)
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let fromVC = transitionContext.viewController(forKey: .from)!
        guard let photosReviewVC = transitionContext.viewController(forKey: .to) as? PhotosReviewViewController else {
            return
        }

        photosReviewVC.view.frame = transitionContext.finalFrame(for: photosReviewVC)
        photosReviewVC.view.alpha = 0
        // this won't animate but will change to 1 on completion, not to interfere with transition
        // view animation
        photosReviewVC.scrollView.alpha = 0
        let photosReviewBackgroundColor = photosReviewVC.view.backgroundColor
        // photosReview is rendered on top of transition view so it needs to be transparent for the time
        // of transition
        photosReviewVC.view.backgroundColor = .clear

        // hide immediately as we will move the transition view (with same photo) and they
        // cannot be both visible at the same time
        referenceImageView.alpha = 0

        let transitionView = UIImageView(image: referenceImageView.image)
        transitionView.contentMode = .scaleAspectFit
        transitionView.layer.cornerRadius = referenceImageView.layer.cornerRadius
        transitionView.clipsToBounds = true
        transitionView.frame = containerView.convert(referenceImageView.bounds, from: referenceImageView)
        containerView.addSubview(transitionView)

        containerView.addSubview(photosReviewVC.view)

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            dampingRatio: 1.0
        ) {
            fromVC.view.alpha = 0
            photosReviewVC.view.alpha = 1
            transitionView.frame = photosReviewVC.view.frame
            transitionView.center = photosReviewVC.view.center
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            self.referenceImageView.alpha = 1
            photosReviewVC.scrollView.alpha = 1
            photosReviewVC.view.backgroundColor = photosReviewBackgroundColor
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        animator.startAnimation()
    }
}

/// Zoom out from the PhotosReviewViewController
class PhotosReviewDismissalAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
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

    /// Reuse animator for subsequent calls to `animateTransition` otherwise the interactive transition doesn't work
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning)
        -> UIViewImplicitlyAnimating
    {
        // as per documentation, the same object should be returned for the ongoing transition
        if let animatorForCurrentSession = animatorForCurrentTransition {
            return animatorForCurrentSession
        }

        let containerView = transitionContext.containerView
        guard let photosReviewVC = transitionContext.viewController(forKey: .from) as? PhotosReviewViewController else {
            fatalError("Transition not used with PhotosReviewViewController")
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
        // so the buttons of PhotosReviewVC are on top of the transition view
        containerView.insertSubview(transitionView, belowSubview: photosReviewVC.view)

        let photosReviewBackgroundColor = photosReviewVC.view.backgroundColor
        // photosReview rendered on top of transition view so it needs to be transparent for the time
        // of transition
        photosReviewVC.view.backgroundColor = .clear

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            dampingRatio: 1.0
        ) {
            photosReviewVC.view.alpha = 0
            toVC.view.alpha = 1
            transitionView.layer.cornerRadius = 13
            transitionView.frame = targetFrame
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            photosReviewVC.view.alpha = 1
            self.targetView.alpha = 1
            self.referenceImageView.alpha = 1
            photosReviewVC.view.backgroundColor = photosReviewBackgroundColor
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animatorForCurrentTransition = animator

        return animator
    }

    /// animate from a PhotosReviewViewController to a view controller with targetView and targetFrame for the image by animating fromVC.alpha to 0,
    /// animating toVC to 1 and animating the size/position of a photo (for this we create a transition view with same image so the
    /// original and target image/gallery stay untouched)
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }
}
