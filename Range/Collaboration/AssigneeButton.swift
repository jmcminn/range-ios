import Foundation
import UIKit

/// Displays a button for assignee.
class AssigneeButton: UIButton {
    /// The assignee
    var assignee: Participant? {
        didSet { updateButton() }
    }

    init() {
        super.init(frame: .zero)

        setupButton()
        updateButton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Update the content when on assignee change
    private func updateButton() {
        updateTitle()
        updateImage()
    }

    override open var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted
                ? .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
                : .dynamic(.Neutral_09)
        }
    }

    /// Setup the button configuration
    private func setupButton() {
        // because of a bug that doesn't allow for limiting the number of lines for
        // UIButton title to 1 for buttons configured using UIButton.Configuration
        // we need to use the old way of configuring the button
        // bug: https://developer.apple.com/forums/thread/699622
        setInsets(
            forContentPadding: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8),
            imageTitlePadding: 8
        )
        contentHorizontalAlignment = .leading
        titleLabel?.numberOfLines = 2
        titleLabel?.lineBreakMode = .byTruncatingTail

        backgroundColor = .dynamic(.Neutral_09)
        layer.cornerRadius = 8
        layer.borderWidth = 1

        updateColors()
    }

    /// update colors
    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateTitle()
        updateImage()
        updateColors()
    }

    private func updateColors() {
        layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }

    /// Updates the title (both, the content and colors)
    private func updateTitle() {
        if let assignee = assignee {
            // we cannot use UIButton.subtitle, it's only supported when using configuration
            // so let's make a 2 line title (and title is limited to 2 lines so if the
            // assignee name is too long it'll be truncated)
            let title = NSMutableAttributedString(
                string: "Assigned to\n",
                attributes: [
                    .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
                    .font: UIFont._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold),
                ]
            )
            title.append(NSAttributedString(string: assignee.displayName, attributes: [
                .foregroundColor: chooseColor(light: .Neutral_07, dark: .Neutral_04),
                .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
            ]))
            setAttributedTitle(title, for: .normal)
        } else {
            let title = NSMutableAttributedString(
                string: "Assignee",
                attributes: [
                    .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
                    .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
                ]
            )
            setAttributedTitle(title, for: .normal)
        }
    }

    /// Updates the image, whenever assignee changes or we have color style change)
    private func updateImage() {
        // TODO: add assignee image
//        if assignee != nil {
//        } else {
        let image = UIImage(
            systemName: "person",
            withConfiguration: UIImage
                .SymbolConfiguration(font: UIFont
                    ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold))
        )?
            .withTintColor(chooseColor(light: .Neutral_07, dark: .Neutral_04),
                           renderingMode: .alwaysTemplate)
        let imageWithBackground = image?.addCircleBackground(
            bgSize: CGSize(width: 32, height: 32),
            bgColor: chooseColor(.Neutral_10),
            strokeColor: chooseColor(light: .Neutral_04, dark: .Neutral_07)
        )
        setImage(imageWithBackground, for: .normal)
        setImage(imageWithBackground, for: .highlighted)
//        }
    }
}
