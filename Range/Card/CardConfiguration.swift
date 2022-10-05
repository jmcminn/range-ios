import Foundation

/// Configuration for card presentation, modal or non modal.
/// Some properties are valid only for a particular presentation style - see the properties documentation.
struct CardConfiguration {
    var initialCardPosition: CardPosition = .min

    /// Whether user can drag the card (when interactive = `true`) or the card can only be displayed and positioned programmatically.
    ///
    /// - Warning: only for non-modal card presentation
    var interactive: Bool = true

    /// Whether the card can go full screen = cover the top safe area
    ///
    /// - Warning: only for non-modal card presentation
    var allowsFullScreen: Bool = false

    /// Whether the overlay is shown over the presenting view.
    /// If overlay is shown it makes the presenting view not interactive.
    ///
    /// - Warning: only for non-modal card presentation
    var showOverlay: Bool = false

    /// Show the blur over the presented card in the bottom safe area, `false` by default
    ///
    /// - Warning: only for modal card presentation
    var showSafeAreaBlur: Bool = false

    /// slider is a little rounded rectangle on the top of the presentedView that shows user it can be dragged
    ///
    /// - Warning: only for modal card presentation
    var showSliderView: Bool = true
}
