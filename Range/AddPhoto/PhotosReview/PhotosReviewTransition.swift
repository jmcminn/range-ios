import Foundation
import UIKit

// TODO: 227 interactive dismissal
//     install pan gesture recognizer in PhotosReviewViewController to dismiss
//     galleryVC.setCurrentPage(vc.currentPage)
//     set imageHeight2Width and then ask for current page frame...

// Good set of articles on view controller transitions: https://danielgauthier.me/2020/02/19/indie-4.html
// although this was still more based on: https://github.com/zvonicek/ImageSlideshow/blob/master/ImageSlideshow/Classes/Core/ZoomAnimatedTransitioning.swift

/// Support transitioning from a view controller with photo to full screen PhotosReviewViewController
class PhotosReviewTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    weak var galleryVC: ImageGalleryViewController<String>?
    weak var photosReviewVC: PhotosReviewViewController?

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
            fromVC.view.alpha = 1
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

    /// animate from a PhotosReviewViewController to a view controller with targetView and targetFrame for the image by animating fromVC.alpha to 0,
    /// animating toVC to 1 and animating the size/position of a photo (for this we create a transition view with same image so the
    /// original and target image/gallery stay untouched)
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let photosReviewVC = transitionContext.viewController(forKey: .from) as? PhotosReviewViewController else {
            return
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
        animator.startAnimation()
    }
}
