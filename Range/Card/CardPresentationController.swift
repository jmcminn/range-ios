import UIKit

// This implementation is based on https://github.com/applidium/ADOverlayContainer and https://github.com/babylonhealth/DrawerKit

/**
 A custom UIPresentationController to present view controllers in a way similar to Apple [sheets](https://developer.apple.com/design/human-interface-guidelines/ios/views/sheets/)

 It adds a pan gesture recognizer to the presented view to allow for dragging the card up/down.

 It supports 3 predefined card positions to which the presented card snaps - see ``CardPresentable`` and ``CardPosition`` for more details

 It also registers itself as a delegate for ``CardPresentable/drivingScrollView()-2kjov``.
 So if the presented card contains a scroll view, it's behavior will change so it only scrolls vertically if the card is at its full height, otherwise it'll drag the card.
 */
class CardPresentationController: UIPresentationController {
    let cardConfig: CardConfiguration
    var cardHandler: CardHandler?
    var presentationContainerView: PresentationContainerView!
    var blurView: UIView?
    var sliderView: UIView?

    init(presentedViewController: UIViewController & CardPresentable,
         presenting presentingViewController: UIViewController?, cardConfig: CardConfiguration)
    {
        self.cardConfig = cardConfig
        super.init(
            presentedViewController: presentedViewController,
            presenting: presentingViewController
        )
    }

    override func presentationTransitionWillBegin() {
        setupPresentationContainerView()
        presentedViewController.loadViewIfNeeded()
        if let containerView = containerView {
            cardHandler = CardHandler(
                presentedViewController: presentedViewController as! CardPresentable,
                containerView: containerView,
                config: cardConfig
            )
            cardHandler?.install()
        } else {
            print("containerView is nil, cannot install the card handler")
        }
        setupSafeAreaBlur()
        setupSliderView()
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override func dismissalTransitionDidEnd(_: Bool) {
        removePresentationContainerView()
        cardHandler?.remove()
        removeSafeAreaBlur()
        removeSliderView()
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let cardHandler = cardHandler else { return .zero }
        let targetHeight = cardHandler.cardHeight(forPosition: cardHandler.position)
        var frame = cardHandler.containerView.bounds
        frame.origin.y = frame.size.height - targetHeight
        frame.size.height = cardHandler.maxAllowedCardHeight
        return frame
    }

    /**
     The default containerView accepts all user interaction and doesn't let the view from presentingViewController respond.
     This method replaces it with a view that will pass the touches through to touchDelegate which in turn will direct them to the presenting view.
     This way user can interact with the original view while the card view is presented on the screen.
     */
    func setupPresentationContainerView() {
        guard self.presentationContainerView == nil else { return }

        let presentationContainerView = PresentationContainerView()
        presentationContainerView.touchDelegate = self
        presentationContainerView.backgroundColor = .clear
        presentationContainerView.frame = containerView?.superview?.frame ?? .zero
        presentationContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if let containerView = containerView {
            containerView.superview?.addSubview(presentationContainerView)
            presentationContainerView.addSubview(containerView)
        }

        self.presentationContainerView = presentationContainerView
    }

    func removePresentationContainerView() {
        // the containerView is removed by UIKit when dismissal ends
        // so it's not necessary to restore it in its original superview
        presentationContainerView.removeFromSuperview()
    }
}

extension CardPresentationController: PresentationContainerViewDelegate {
    func view(_ view: PresentationContainerView, shouldPassthroughTouchAt point: CGPoint) -> Bool {
        guard let presentedView = presentedView else { return false }
        return !presentedView.bounds.contains(presentedView.convert(point, from: view))
    }

    func view(_: PresentationContainerView, forTouchAt _: CGPoint) -> UIView? {
        presentingViewController.view
    }
}

/// Bluring
extension CardPresentationController {
    func setupSafeAreaBlur() {
        guard cardConfig.showSafeAreaBlur else { return }

        let blur = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blur)
        presentationContainerView.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(presentationContainerView.safeAreaInsets.bottom)
        }
        self.blurView = blurView
    }

    func removeSafeAreaBlur() {
        if let blurView = blurView {
            blurView.removeFromSuperview()
        }
    }
}

/// Slider
extension CardPresentationController {
    func setupSliderView() {
        guard cardConfig.showSliderView else { return }

        let sliderView = UIView()
        sliderView.backgroundColor = UIColor.Neutral_06
        sliderView.layer.cornerRadius = 2.5
        presentedView?.addSubview(sliderView)
        sliderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(33)
            make.height.equalTo(5)
            make.top.equalTo(8)
        }
        self.sliderView = sliderView
    }

    func removeSliderView() {
        if let sliderView = sliderView {
            sliderView.removeFromSuperview()
        }
    }
}
