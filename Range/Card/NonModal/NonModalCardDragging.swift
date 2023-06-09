import UIKit

/// Since non modal cards can be shown and hidden multiple times we need to track the card hidden state.
class NonModalCardDragging: CardDragging {
    /// Hide the read/write variable, so it's only controlled by `showCard` and `hideCard`
    fileprivate var cardHidden = true

    private var overlayView: UIView?
    private var blurView: UIView?

    override init(
        presentedViewController: UIViewController & CardPresentable,
        containerView: UIView,
        config: CardConfiguration
    ) {
        super.init(presentedViewController: presentedViewController, containerView: containerView, config: config)
        setInitialCardFrame()

        if config.showOverlay {
            let overlayView = UIView()
            overlayView.backgroundColor = .dynamic(.Neutral_01).withAlphaComponent(0.4)
            overlayView.isHidden = true
            containerView.insertSubview(overlayView, belowSubview: presentedViewController.view)
            overlayView.snp.makeConstraints { make in make.edges.equalToSuperview() }
            overlayView.isUserInteractionEnabled = true
            overlayView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(overlayTapped)))
            self.overlayView = overlayView
        }
        if config.showSafeAreaBlur {
            let blur = UIBlurEffect(style: .regular)
            let blurView = UIVisualEffectView(effect: blur)
            containerView.addSubview(blurView)
            blurView.snp.makeConstraints { make in
                make.left.right.bottom.equalToSuperview()
                make.height.equalTo(containerView.safeAreaInsets.bottom)
            }
            blurView.isHidden = true
            self.blurView = blurView
        }
    }

    fileprivate func setInitialCardFrame() {
        var cardFrame = containerView.bounds
        cardFrame.origin.y = containerView.bounds.height
        if config.allowsFullScreen {
            cardFrame.size.height = presentedViewController.height(forContainer: containerView, cardPosition: .max)
        } else {
            cardFrame.size.height = maxAllowedCardHeight
        }
        presentedViewController.view.frame = cardFrame
    }

    /// Is the card currently hidden
    var isCardHidden: Bool {
        cardHidden
    }

    /// Sets the position to last card position before it was hidden
    func showCard(animated: Bool, completion: (() -> Void)? = nil) {
        guard cardHidden else { return }
        cardHidden = false
        setPosition(position, withVelocity: 0, animated: animated, completion: completion)

        // show overlay if present
        if let overlayView = overlayView {
            overlayView.isHidden = false
            overlayView.alpha = 0
            UIView.animate(withDuration: 0.1) {
                overlayView.alpha = 1
            }
        }
        blurView?.isHidden = false
    }

    /// Hides card = moves it off the screen
    func hideCard(animated: Bool, completion: (() -> Void)? = nil) {
        guard !cardHidden else { return }
        cardHidden = true
        // ends editing when hiding the card - this will hide the keyboard
        presentedViewController.view.endEditing(true)
        setCardHeight(0, animated: animated, completion: completion)

        // hide overlay if present
        if let overlayView = overlayView {
            UIView.animate(withDuration: 0.1,
                           animations: {
                               overlayView.alpha = 0
                           }, completion: { _ in
                               overlayView.isHidden = true
                           })
        }
        blurView?.isHidden = true
    }

    override func remove() {
        super.remove()
        overlayView?.removeFromSuperview()
        overlayView = nil
        blurView?.removeFromSuperview()
        blurView = nil
    }

    /// When tapped on the overlay
    @objc private func overlayTapped() {
        delegates.values.forEach { $0.cardOverlayTapped() }
    }
}
