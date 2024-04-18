import UIKit

/// Extension of UIButton that allows to set tapInset to allow tapping outside of a button (for small buttons for which
/// we need bigger tap area than the button frame size).
/// It adds the custom disabled state - making the button opacity = 50%
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

    /// remember if the defauls were set already
    private var defaultsSet = false
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

        guard let configuration else { return }

        if !defaultsSet {
            defaultsSet = true
            defaultForegroundColor = configuration.baseForegroundColor
            defaultStrokeColor = configuration.background.strokeColor
        }

        var updatedConfig = configuration

        let baseBackgroundColor = configuration.baseBackgroundColor
        if let baseBackgroundColor {
            updatedConfig.background.backgroundColor = baseBackgroundColor
        }

        switch state {
        case .disabled:
            updatedConfig.background.backgroundColor = baseBackgroundColor?.withAlphaComponent(0.5)
            updatedConfig.baseForegroundColor = defaultForegroundColor?.withAlphaComponent(0.5)
            // HACK: in the disabled state the baseForegroundColor is ignored... we need to apply
            // directly to the title string
            updatedConfig.attributedTitle = updatedConfig.attributedTitle?.settingAttributes(
                AttributeContainer([.foregroundColor: defaultForegroundColor?.withAlphaComponent(0.5) ?? .red])
            )
            updatedConfig.background.strokeColor = defaultStrokeColor?.withAlphaComponent(0.5)

        case [.highlighted, .selected]:
            if _withCustomRangeHighlightColor, let selectionBackgroundColor {
                updatedConfig.background.backgroundColor = selectionBackgroundColor._highlightColor
            }
            updatedConfig.baseForegroundColor = selectionForegroundColor ?? defaultForegroundColor
            updatedConfig.background.strokeColor = selectionStrokeColor ?? defaultStrokeColor

        case .highlighted:
            if _withCustomRangeHighlightColor {
                updatedConfig.background.backgroundColor = baseBackgroundColor?._highlightColor
            }
            updatedConfig.baseForegroundColor = defaultForegroundColor
            updatedConfig.background.strokeColor = defaultStrokeColor

        case .selected:
            if let selectionBackgroundColor {
                updatedConfig.background.backgroundColor = selectionBackgroundColor
            }
            updatedConfig.baseForegroundColor = selectionForegroundColor ?? defaultForegroundColor
            updatedConfig.background.strokeColor = selectionStrokeColor ?? defaultStrokeColor

        default:
            // the default .normal (and all not handled states)
            updatedConfig.baseForegroundColor = defaultForegroundColor
            updatedConfig.background.strokeColor = defaultStrokeColor
        }

        self.configuration = updatedConfig
    }
}
