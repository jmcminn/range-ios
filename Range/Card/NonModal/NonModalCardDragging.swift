import UIKit

/// Since non modal cards can be shown and hidden multiple times we need to track the card hidden state.
class NonModalCardDragging: CardDragging {
    /// Hide the read/write variable, so it's only controlled by `showCard` and `hideCard`
    fileprivate var cardHidden = true

    private var overlayView: UIView?

    override init(
        presentedViewController: UIViewController & CardPresentable,
        containerView: UIView,
        config: CardConfiguration
    ) {
        super.init(presentedViewController: presentedViewController, containerView: containerView, config: config)
        setInitialCardFrame()

        if config.showOverlay {
            let overlayView = UIView()
            overlayView.backgroundColor = .dynamicColor(light: .Neutral_10, dark: .Neutral_01).withAlphaComponent(0.4)
            overlayView.isHidden = true
            containerView.insertSubview(overlayView, belowSubview: presentedViewController.view)
            overlayView.snp.makeConstraints { make in make.edges.equalToSuperview() }
            self.overlayView = overlayView
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
    }

    /// Hides card = moves it off the screen
    func hideCard(animated: Bool, completion: (() -> Void)? = nil) {
        guard !cardHidden else { return }
        cardHidden = true
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
    }
}
