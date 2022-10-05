import UIKit

/// Card can be presented in 3 positions with heights defined by the CardPresentable protocol.
/// `.medium` position is optional => if it's height is < 0 then only min and max will be used
enum CardPosition: Int, CaseIterable {
    case min = 0 // typically just the header is visible
    case medium // header + some content is visible
    case max // the view takes the whole screen
}

/// To be implemented by view controllers that need to be shown as modal or non modal cards
protocol CardPresentable: UIViewController {
    /// The height at which the card must be presented for given position.
    /// If negative then position is not supported (only works for medium)
    /// Passing container view allows to calculate the card height based on container width, height or safe areas...
    ///
    /// - parameters: cardContainerView - container view in which the card is presented
    /// - parameters: cardPosition - position for which to return height
    func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat

    /// If provided the scroll view will be used to drive the card view panning
    func drivingScrollView() -> UIScrollView?
}

/// Default implementations for optional CardPresentable functions
extension CardPresentable {
    func drivingScrollView() -> UIScrollView? { nil }
}
