import UIKit

/// Cell used to display TagViewModel items
class TagSelectionTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleView = UILabel()
    private var selectedObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:

        iconView.tintColor = .dynamic(.Neutral_04)
        titleView.textColor = iconView.tintColor
        titleView.adjustsFontForContentSizeCategory = true

        contentView.addSubview(iconView)
        contentView.addSubview(titleView)

        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalTo(contentView.snp.leadingMargin).offset(24)
        }
        titleView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(14)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(44)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// whether to show the tag count
    var showTagCount: Bool = true

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

                let tagName = tagViewModel.id == TagViewModel.untaggedId ? "Show untagged pins" : tagViewModel.name
                let attributedText = NSMutableAttributedString(
                    string: tagName,
                    attributes: [
                        .foregroundColor: chooseColor(.Neutral_04),
                        .font: UIFont.preferredFont(forTextStyle: .body),
                    ]
                )
                if showTagCount, tagViewModel.id != TagViewModel.untaggedId {
                    attributedText.append(NSAttributedString(
                        string: " (\(tagViewModel.usageCount))",
                        attributes: [
                            .foregroundColor: UIColor.dynamic(.Neutral_05),
                            .font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
                        ]
                    ))
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
                attributes: [
                    .foregroundColor: UIColor.dynamic(.Neutral_05),
                    .font: UIFont.preferredFont(forTextStyle: .body),
                ]
            )
        if let range = attributedText.string.range(of: "'\(name)'") {
            let nsRange = NSRange(range, in: attributedText.string)
            attributedText.setAttributes([
                .foregroundColor: UIColor.dynamic(.Neutral_04),
                .font: UIFont.preferredFont(forTextStyle: .body),
            ], range: nsRange)
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
                                                bgColor: .dynamic(.Neutral_10),
                                                strokeColor: .dynamic(.Neutral_07))
        } else {
            iconView.image = nil
        }
    }

    override func prepareForReuse() {
        tagViewModel = nil
    }
}
