import UIKit

/// A protocol that objects interested in coordinating non modal card presentations must conform to.
///
/// The most common use case is for the view controller presented as a card to implement this protocol,
/// so from now on the coordinating controller will be refered to as a card view controller.
///
/// Non modal presentation is just adding a child view controller to presenting view controller and installing
/// a `CardHandler` for card dragging.
///
/// The usage pattern is as follows
/// 1. presenting view controller installs a card by calling `installCard` and providing view controller
/// to display as a card and its card configuration. After installing the card is not yet visible.
/// 2. To show a card call `showCard` on card view controller
/// 3. The card can also be hidden with `hideCard`.
/// After card is installed it can be shown and hidden multiple times
/// 4. When the card is no longer needed it can be removed by calling `removeCard` on the presenting view controller
protocol NonModalCardCoordinating: UIViewController {
    var cardDragging: NonModalCardDragging? { get set }
}

/// Extensions for installing and removing a card on a presenting view controller
extension UIViewController {
    /// Installs the `cardViewController` in this view controller
    /// - Parameter inView: the view to which the card subview will be added. If `nil` then added to this controller `view`
    func installCard(
        cardViewController: CardPresentable & NonModalCardCoordinating,
        inView: UIView? = nil,
        cardConfig: CardConfiguration = CardConfiguration()
    ) {
        add(childController: cardViewController, toView: inView)
        let containerView: UIView = inView ?? view
        let cardDragging = NonModalCardDragging(
            presentedViewController: cardViewController,
            containerView: containerView,
            config: cardConfig
        )
        cardViewController.cardDragging = cardDragging
        if cardConfig.interactive {
            cardDragging.install()
        }
    }

    func removeCard(cardViewController: CardPresentable & NonModalCardCoordinating) {
        cardViewController.cardDragging?.remove()
        cardViewController.cardDragging = nil
        remove(childController: cardViewController)
    }
}

/// extensions for showing and hiding a card on the card view controller.
extension NonModalCardCoordinating {
    func showCard(animated: Bool, completion: (() -> Void)? = nil) {
        guard let cardDragging = cardDragging else {
            fatalError("view controller not installed as a card")
        }
        cardDragging.showCard(animated: animated, completion: completion)
    }

    func hideCard(animated: Bool, completion: (() -> Void)? = nil) {
        guard let cardDragging = cardDragging else {
            fatalError("view controller not installed as a card")
        }
        cardDragging.hideCard(animated: animated, completion: completion)
    }
}
