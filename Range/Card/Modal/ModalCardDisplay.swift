import UIKit

/**
 This file defines protocols for coordinating displaying view controllers with ``ModalCardPresentationController``.

 Similarly to sheet presentation which is configured using `UIViewController.sheetPresentationController,
 to present using cards we need to store the transitioningDelegate and the card configuration somewhere.
 This is realised by the `ModalCardDisplayController` which coordinates by registering as the transitioningDelegate
 and passing the `CardConfiguration` to `ModalCardPresentationController`.
 */

/// A protocol that objects interested in coordinating modal card presentations must conform to.
protocol ModalCardCoordinating: UIViewController {
    /// An object vended by the conforming object, whose responsibility is to control
    /// the presentation, animation, and interactivity of/with the drawer.
    var modalCardDisplayController: ModalCardDisplayController? { get set }

    func installModalCardDisplayController(cardConfig: CardConfiguration)
}

extension ModalCardCoordinating {
    /// By default ModalCardDisplayController is set as the transitioningDelegate to provide the presentation controller
    func installModalCardDisplayController(cardConfig: CardConfiguration) {
        modalPresentationStyle = .custom
        modalCardDisplayController = ModalCardDisplayController(cardConfig: cardConfig)
        transitioningDelegate = modalCardDisplayController
    }
}

/// Class to store the `CardConfiguration` and provide the `ModalCardPresentationController` when presenting a view controller modally.
class ModalCardDisplayController: NSObject, UIViewControllerTransitioningDelegate {
    let cardConfig: CardConfiguration
    init(cardConfig: CardConfiguration) {
        self.cardConfig = cardConfig
        super.init()
    }

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source _: UIViewController
    ) -> UIPresentationController? {
        ModalCardPresentationController(
            presentedViewController: presented as! CardPresentable,
            presenting: presenting,
            cardConfig: cardConfig
        )
    }
}
