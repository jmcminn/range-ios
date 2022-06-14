import CoreMIDI
import UIKit

/// Extend UIButton to provide higher hit area for the segmented control buttons - the view itself is pretty
/// low (32 points) and the buttons even lower (28 points), so let's add 10 points on the top and bottom.
class SegmentedControlButton: UIButton {
    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let biggerFrame = bounds.insetBy(dx: 0, dy: -10)

        return biggerFrame.contains(point)
    }
}

/// Custom implementation of UISegmentedControl because:
/// - the iOS component doesn't support setting background
/// - it adds the shadow for selected element in the light mode
/// - it doesn't allow to display image+text for a segment
///
/// - Warning: some colors need to be manually updated on user interface style change (dark/light)
///             as it's applied as CGColor - use `updateColors` function for this.
class SegmentedControl: UIView {
    // hardcoded view height
    static let height = 32.0
    // horizontal spacing between buttons
    private static let buttonsSpacing = 5.0
    // space between buttons and view bounds
    private static let contentPadding = 2.0

    /// The index number that identifies the selected segment that the user last touched.
    var selectedSegmentIndex: Int = 0

    /// current width of the button
    private var buttonWidth: CGFloat = 0.0

    /// The selection view that moves behind buttons when segment is selected
    private var selectedSegmentIndicator: UIView!
    /// Buttons corresponding to provided items
    private var buttons: [UIButton]!
    /// Separators between buttons
    private var separators: [UIView]!

    init(items: [UIAction]) {
        super.init(frame: .zero)

        setupView()
        buildButtons(actions: items)
        buildSeparators()
        buildSelectedSegmentIndicator()
        updateColors()
        setSelectedSegmentIndex(0, animated: false)

        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override to detect points in the SegmentedControlButton(s) which have frames outside the view bounds
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            subview.point(inside: convert(point, to: subview), with: event)
        }
    }

    /// Override to calculate the current width for buttons and selected segment and positions for separators
    override func layoutSubviews() {
        super.layoutSubviews()

        // update as the view bounds might have changed
        buttonWidth = calcualteButtonWidth()

        updateButtonsFrames()
        updateSeparatorsFrames()
        updateSelectedSegmentIndicatorFrame()
    }

    /// updates the current selected index
    private func setSelectedSegmentIndex(_ index: Int, animated: Bool) {
        selectedSegmentIndex = index
        /// update the configuration based on the selected index
        updateButtonsSelectedStyle()
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.updateSelectedSegmentIndicatorFrame()
                self.updateSeparatorsAlpha()
            }
        } else {
            updateSelectedSegmentIndicatorFrame()
            updateSeparatorsAlpha()
        }
    }

    /// sets the buttons frames based on the current bounds
    private func updateButtonsFrames() {
        // do not use autolayout, it's easier to just calculate and set the frames
        for (index, button) in buttons.enumerated() {
            button.frame = buttonFrame(atIndex: index)
            button.setNeedsLayout()
        }
    }

    /// sets the separator frames based on the current bounds
    private func updateSeparatorsFrames() {
        // do not use autolayout, it's easier to just calculate and set the frames
        for (index, separator) in separators.enumerated() {
            separator.frame.origin.x = SegmentedControl.contentPadding
                + Double(index + 1) * (buttonWidth + SegmentedControl.buttonsSpacing)
                - SegmentedControl.buttonsSpacing / 2.0
        }
    }

    /// Updates the frame of the indicator
    private func updateSelectedSegmentIndicatorFrame() {
        selectedSegmentIndicator.frame = buttonFrame(atIndex: selectedSegmentIndex)
    }

    /// Updates the separators alpha
    /// separators adjacent to current selected index should be hidden
    private func updateSeparatorsAlpha() {
        for (index, separator) in separators.enumerated() {
            if index == selectedSegmentIndex || index == selectedSegmentIndex - 1 {
                separator.alpha = 0
            } else {
                separator.alpha = 1
            }
        }
    }

    /// Calcualtes the frame for a button at given index
    private func buttonFrame(atIndex index: Int) -> CGRect {
        // for the last button align it to the right, as rounding down may result in too big padding on the right
        let x = index == buttons.count - 1
            ? frame.width - SegmentedControl.contentPadding - buttonWidth
            : SegmentedControl.contentPadding + (buttonWidth + SegmentedControl.buttonsSpacing) * Double(index)
        return CGRect(
            x: x,
            y: SegmentedControl.contentPadding,
            width: buttonWidth,
            height: SegmentedControl.height - 2 * SegmentedControl.contentPadding
        )
    }

    /// Calculates the button width based on current view width and buttonsSpacing
    private func calcualteButtonWidth() -> CGFloat {
        let spaceForButtons: CGFloat = bounds.width -
            SegmentedControl.buttonsSpacing * Double(buttons.count - 1)
            - 2 * SegmentedControl.contentPadding
        return (spaceForButtons / Double(buttons.count)).rounded(.down)
    }

    /// Setup the background, corner of the view
    private func setupView() {
        layer.cornerRadius = 9
        layer.borderWidth = 1
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
    }

    /// Builds the buttons from actions
    private func buildButtons(actions: [UIAction]) {
        // because of a bug that doesn't allow for limiting the number of lines for
        // UIButton title to 1 for buttons configured using UIButton.Configuration
        // we need to use the old way of configuring the button
        // bug: https://developer.apple.com/forums/thread/699622
        buttons = actions.map { action in
            SegmentedControlButton(primaryAction: action)
        }
        for (index, button) in buttons.enumerated() {
            button.setInsets(
                forContentPadding: UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5),
                imageTitlePadding: 5
            )
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.lineBreakMode = .byTruncatingMiddle
            button.addAction(UIAction(handler: { [weak self] _ in
                self?.setSelectedSegmentIndex(index, animated: true)
            }), for: .touchUpInside)
        }
        buttons.forEach(addSubview)
    }

    /// Update the font, image size and color based on the selected segment
    private func updateButtonsSelectedStyle() {
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedSegmentIndex
            button.tintColor = selected
                ? .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
                : .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
            button.titleLabel?.font = UIFont.systemFont(
                ofSize: 13,
                weight: selected ? .semibold : .medium
            )
            button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(
                pointSize: 13,
                weight: selected ? .semibold : .medium
            ), forImageIn: .normal)
        }
    }

    /// Builds vertical separators between buttons
    private func buildSeparators() {
        separators = (1 ..< buttons.count).map { _ in
            let separator = UIView(frame: CGRect(
                x: 0, // will be updated later as each separator differs in x only
                y: 8,
                width: 1 / UIScreen.main.scale, // 1 pixel
                height: SegmentedControl.height - 2 * 8
            ))
            separator.backgroundColor = .Neutral_06
            return separator
        }
        separators.forEach(addSubview)
    }

    /// Builds the indicator view that moves when user is tapping on buttons
    private func buildSelectedSegmentIndicator() {
        selectedSegmentIndicator = UIView()
        selectedSegmentIndicator.layer.cornerRadius = 7
        selectedSegmentIndicator.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        insertSubview(selectedSegmentIndicator, at: 0)
    }

    /// Adapt CG colors to interface style change
    public func updateColors() {
        layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
    }
}
