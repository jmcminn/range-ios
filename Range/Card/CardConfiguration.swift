import Foundation

/// Configuration for CardPresentationController
struct CardConfiguration {
    var initialCardPosition: CardPosition = .min

    /// Show the blur over the presented card in the bottom safe area, `false` by default
    var showSafeAreaBlur: Bool = false

    /// slider is a little rounded rectangle on the top of the presentedView that shows user it can be dragged
    var showSliderView: Bool = true
}
