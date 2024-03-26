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

    /// Color overrides for selection state
    private(set) var selectionBackgroundColor: UIColor?
    private(set) var selectionForegroundColor: UIColor?
    private(set) var selectionStrokeColor: UIColor?
    /// Storing original values of colors for selection state overrides (these colors will be overriden in the configuration)
    private(set) var defaultForegroundColor: UIColor?
    private(set) var defaultStrokeColor: UIColor?

    /// When called it overrides given colors when the control is in the selected state
    func withSelectionConfig(backgroundColor: UIColor? = nil,
                             foregroundColor: UIColor? = nil,
                             strokeColor: UIColor? = nil) -> Self
    {
        selectionBackgroundColor = backgroundColor
        selectionForegroundColor = foregroundColor
        selectionStrokeColor = strokeColor
        defaultForegroundColor = configuration?.baseForegroundColor
        defaultStrokeColor = configuration?.background.strokeColor
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
        var updatedConfig = configuration

        if _withCustomRangeHighlightColor || selectionBackgroundColor != nil {
            guard let baseBackgroundColor = configuration.baseBackgroundColor else {
                fatalError("baseBackgroundColor not defined for a button")
            }
            switch state {
            case .normal:
                // use the color as provided, with no adjustments
                updatedConfig.background.backgroundColor = baseBackgroundColor
            case [.highlighted]:
                if _withCustomRangeHighlightColor {
                    updatedConfig.background.backgroundColor = baseBackgroundColor._highlightColor
                }
            case .selected:
                if let selectionBackgroundColor {
                    updatedConfig.background.backgroundColor = selectionBackgroundColor
                }
            default:
                // no update to color
                break
            }
        }
        if let selectionForegroundColor {
            switch state {
            case .selected:
                updatedConfig.baseForegroundColor = selectionForegroundColor
            default:
                updatedConfig.baseForegroundColor = defaultForegroundColor
            }
        }
        if let selectionStrokeColor {
            switch state {
            case .selected:
                updatedConfig.background.strokeColor = selectionStrokeColor
            default:
                updatedConfig.background.strokeColor = defaultStrokeColor
            }
        }

        self.configuration = updatedConfig
    }
}
