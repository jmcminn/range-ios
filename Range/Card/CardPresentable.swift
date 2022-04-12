import UIKit

/// Card can be presented in 3 positions with heights defined by the CardPresentable protocol.
/// `.medium` position is optional => if it's height is < 0 then only min and max will be used
enum CardPosition: Int, CaseIterable {
    case min = 0 // typically just the header is visible
    case medium // header + some content is visible
    case max // the view takes the whole screen
}

/// To be implemented by view controllers that need to be shown using CardPresentationController.
protocol CardPresentable: UIViewController {
    // MARK: - Input for CardPresentationController

    /// The height at which the drawer must be presented for given position. If negative then position is not supported (only works for medium)
    func height(forWidth width: CGFloat, cardPosition: CardPosition) -> CGFloat

    /// If provided the scroll view will be used to drive the card view panning
    func drivingScrollView() -> UIScrollView?

    // MARK: - Output for CardPresentable

    /// Notifies the delegate about position change starting
    func cardWillChangePosition(_ position: CardPosition)

    /// Notifies the delegate about position change
    func cardDidChangePosition(_ position: CardPosition)
}

/// Default implementations for optional CardPresentable functions
extension CardPresentable {
    func drivingScrollView() -> UIScrollView? { nil }
    func cardWillChangePosition(_: CardPosition) {}
    func cardDidChangePosition(_: CardPosition) {}
}
