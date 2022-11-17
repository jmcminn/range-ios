import UIKit

/// Cell used to display TagViewModel items
class TagSelectionTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleView = UILabel()
    private var selectedObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:

        iconView.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        titleView.textColor = iconView.tintColor

        contentView.addSubview(iconView)
        contentView.addSubview(titleView)

        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalTo(contentView.snp.leadingMargin).offset(24)
        }
        titleView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(contentView.snp.leadingMargin).offset(44)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
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

                let countText = "(\(tagViewModel.usageCount))"
                let attributedText =
                    NSMutableAttributedString(
                        string: "\(tagViewModel.name) \(countText)",
                        attributes: [.foregroundColor: chooseColor(light: .Neutral_07, dark: .Neutral_04)]
                    )
                if let range = attributedText.string.range(of: countText) {
                    let nsRange = NSRange(range, in: attributedText.string)
                    let font = UIFont.preferredFont(forTextStyle: .footnote)
                    let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
                    attributedText.setAttributes(
                        [
                            .foregroundColor: UIColor.dynamicColor(light: .Neutral_06, dark: .Neutral_05),
                            .font: boldFont,
                        ],
                        range: nsRange
                    )
                }
                titleView.attributedText = attributedText
            } else {
                titleView.attributedText = nil
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
        titleView.attributedText = attributedText
        iconView.image = UIImage(named: "add_circle")
    }

    /// Update the image based on current tag selection state
    private func updateSelection() {
        if let tagViewModel = tagViewModel {
            iconView.image = nil
            iconView.image = tagViewModel.selected
                ? UIImage(named: "checkmark_checked")
                : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                                bgColor: .dynamicColor(light: .Neutral_01, dark: .Neutral_10),
                                                strokeColor: .dynamicColor(light: .Neutral_04, dark: .Neutral_07))
        } else {
            iconView.image = nil
        }
    }

    override func prepareForReuse() {
        tagViewModel = nil
    }
}
