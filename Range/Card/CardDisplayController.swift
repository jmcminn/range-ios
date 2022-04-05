import UIKit

/**
 This file defines protocols for coordinating displaying view controllers with ``CardPresentationController``.
 
 Similarly to sheet presentation which is configured using `UIViewController.sheetPresentationController,
 to present using cards we need to store the transitioningDelegate and the card configuration somewhere.
 This is realised by the `CardDisplayController` which coordinates by registering as the transitioningDelegate
 and passing the `CardConfiguration` to `CardPresentationController`.
 */

/// A protocol that objects interested in coordinating card presentations must conform to.
protocol CardCoordinating: UIViewController {
    /// An object vended by the conforming object, whose responsibility is to control
    /// the presentation, animation, and interactivity of/with the drawer.
    var cardDisplayController: CardDisplayController? { get set }
    
    func installCardDisplayController(cardConfig: CardConfiguration)
}

extension CardCoordinating {
    /// By default CardDisplayController is set as the transitioningDelegate to provide the presentation controller
    func installCardDisplayController(cardConfig: CardConfiguration) {
        self.modalPresentationStyle = .custom
        cardDisplayController = CardDisplayController(cardConfig: cardConfig)
        self.transitioningDelegate = cardDisplayController
    }
}

/// Class to store the `CardConfiguration` and provide the `CardPresentationController` when presenting a view controller modally.
class CardDisplayController: NSObject, UIViewControllerTransitioningDelegate {
    let cardConfig: CardConfiguration
    init(cardConfig: CardConfiguration) {
        self.cardConfig = cardConfig
        super.init()
    }
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CardPresentationController(presentedViewController: presented as! CardPresentable, presenting: presenting, cardConfig: cardConfig)
    }
}
