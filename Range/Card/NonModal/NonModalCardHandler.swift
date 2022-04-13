import UIKit

/// Since non modal cards can be shown and hidden multiple times we need to track the card hidden state.
class NonModalCardHandler: CardHandler {
    /// Hide the read/write variable, so it's only controlled by `showCard` and `hideCard`
    fileprivate var cardHidden = true

    override init(
        presentedViewController: UIViewController & CardPresentable,
        containerView: UIView,
        config: CardConfiguration
    ) {
        super.init(presentedViewController: presentedViewController, containerView: containerView, config: config)
        setInitialCardFrame()
    }

    fileprivate func setInitialCardFrame() {
        var cardFrame = containerView.bounds
        cardFrame.origin.y = containerView.bounds.height
        cardFrame.size.height = maxAllowedCardHeight
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
    }

    /// Hides card = moves it off the screen
    func hideCard(animated: Bool, completion: (() -> Void)? = nil) {
        guard !cardHidden else { return }
        cardHidden = true
        setCardHeight(0, animated: animated, completion: completion)
    }
}
