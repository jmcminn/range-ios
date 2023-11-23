import UIKit

/// Extension of UIButton that allows to set tapInset to allow tapping outside of a button (for small buttons for which
/// we need bigger tap area than the button frame size).
/// It also customizes the highlight color (when enabled by calling `withCustomRangeHighlightColor`)
class RangeButton: UIButton {
    /// insets for tap area, to make the tap area larger provide negative values
    var tapAreaInsets: UIEdgeInsets = .zero

    /// If set to true then highlight color is "Range custom" set based on the baseBackgroundColor
    private(set) var _withCustomRangeHighlightColor: Bool = false

    /// "builder" like function to return button with insets
    func withTapAreaInsets(_ insets: UIEdgeInsets) -> Self {
        tapAreaInsets = insets
        return self
    }

    /// When called enables custom range highlight color for this button.
    /// It requires that configuration.baseBackgroundColor is set and derives the highlight color from it
    func withCustomRangeHighlightColor() -> Self {
        _withCustomRangeHighlightColor = true
        return self
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let newArea = CGRect(
            x: bounds.origin.x + tapAreaInsets.left,
            y: bounds.origin.y + tapAreaInsets.top,
            width: bounds.size.width - tapAreaInsets.left - tapAreaInsets.right,
            height: bounds.size.height - tapAreaInsets.top - tapAreaInsets.bottom
        )
        return newArea.contains(point)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Overriden to provide custom highlighted color
    override func updateConfiguration() {
        super.updateConfiguration()

        guard let configuration = configuration else {
            return
        }
        var updatedConfiguration = configuration

        if _withCustomRangeHighlightColor {
            guard let baseBackgroundColor = configuration.baseBackgroundColor else {
                fatalError("baseBackgroundColor not defined for a button")
            }
            var background = configuration.background
            background.backgroundColorTransformer = UIConfigurationColorTransformer { incomingColor in
                switch self.state {
                case .normal:
                    // use the color as provided, with no adjustments
                    return baseBackgroundColor
                case [.highlighted]:
                    return baseBackgroundColor._highlightColor
                default:
                    return incomingColor
                }
            }
            updatedConfiguration.background = background
        }

        self.configuration = updatedConfiguration
    }
}
