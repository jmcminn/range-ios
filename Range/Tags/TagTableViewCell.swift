import UIKit

/// Cell used to display TagViewModel items
class TagTableViewCell: UITableViewCell {
    private var selectedObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        imageView?.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        textLabel?.textColor = imageView?.tintColor
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// store the TagViewModel and register for selection observation to update the cell UI
    unowned var tagViewModel: TagViewModel? {
        didSet {
            if let selectedObservation = selectedObservation {
                selectedObservation.invalidate()
            }
            if let tagViewModel = tagViewModel {
                selectedObservation = tagViewModel.observe(
                    \.selected,
                    changeHandler: { [weak self] _, _ in self?.updateSelection() }
                )
                updateSelection()
                textLabel?.text = tagViewModel.name
            } else {
                textLabel?.text = ""
            }
        }
    }

    /// displays a 'create ... tag'
    func displayCreateNewTag(_ name: String) {
        let attributedText =
            NSMutableAttributedString(
                string: "Create '\(name)' tag",
                attributes: [.foregroundColor: UIColor.dynamicColor(light: .Neutral_06, dark: .Neutral_05)]
            )
        if let range = attributedText.string.range(of: "'\(name)'") {
            let nsRange = NSRange(range, in: attributedText.string)
            attributedText.setAttributes(
                [.foregroundColor: UIColor.dynamicColor(light: .Neutral_07, dark: .Neutral_04)],
                range: nsRange
            )
        }
        textLabel?.attributedText = attributedText
        imageView?.image = UIImage(named: "add_circle")
    }

    /// Update the image based on current tag selection state
    private func updateSelection() {
        if let tagViewModel = tagViewModel {
            imageView?.image = nil
            imageView?.image = UIImage(named: tagViewModel.selected
                ? "checkmark_checked"
                : "checkmark_unchecked")
        } else {
            imageView?.image = nil
        }
    }

    override func prepareForReuse() {
        tagViewModel = nil
    }
}
