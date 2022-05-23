Apple Protocols
===============

UIViewControllerTransitioningDelegate to animate a model on- and off-screen
--------------------------------------------------------------------------

Based on [ADOverlayContainer](https://github.com/applidium/ADOverlayContainer)
and [DrawerKit](https://github.com/babylonhealth/DrawerKit)

Pieces

- `UIViewController's` `present()` and `transitioningDelegate` 
- `UIViewControllerTransitioningDelegate`
- `UIPresentationController`
 
- `ModalCardDisplayController`     : a `UIViewControllerTransitioningDelegate`
- `ModalCardPresentationController`: a `UIPresentationController`
- `ModalCardCoordinating`          : installs a `ModalCardDisplayController` for you

When presenting a modal `UIViewController`, **three** `UIViewControllers` are involved:

- the **presenting** controller (where we came from)
- the **presented** controller (where we are going)
- the **presentation** controller (manages the animation from presenting to presented)

Normally when you call:

    presenting.present(presented)

(or similar) Apple provides a default UIPresentationController. 

To override the default, the **presented** `UIViewController` needs a `transitioningDelegate` which 
conforms to `UIViewControllerTransitioningDelegate`. This protocol includes the method:

    presentationController() -> UIPresentationController

In our case, `ModalCardDisplayController` is such a `UIViewControllerTransitioningDelegate` whose 
`presentationController()` method creates a `ModalCardPresentationController` which is a
`UIPresentationController`. 

You **could** use the `ModalCardDisplayController` in any **presented** `UIViewController` using:

    self.modalPresentationStyle = .custom
    self.transitioningDelegate = ModalCardDisplayController(cardConfig: cardConfig)

however `ModalCardCoordinating` will add the method `installModalCardDisplayController`
that does this for you if your **presented** UIViewController extends `ModalCardCoordinating`





