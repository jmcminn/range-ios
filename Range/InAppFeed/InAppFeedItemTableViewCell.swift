import Foundation
import Knock
import UIKit

class InAppFeedItemTableViewCell: UITableViewCell {
    /// The cell has 2 variants based on the reuseIdentifier
    enum Variant: String, CaseIterable {
        case organization = "OrganizationInAppFeedItemCell"
        case project = "ProjectInAppFeedItemCell"

        static func variant(forString: String) -> Variant? {
            Variant.allCases.first { $0.rawValue == forString }
        }
    }

    private let variant: Variant

    private let unreadMarker = UIView()
    private let avatarView = UIView()
    private let stackView = UIStackView()
    private let insertedAtLabel = UILabel()
    private let bottomStroke = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        variant = if let reuseIdentifier { Variant.variant(forString: reuseIdentifier) ?? .project } else { .project }
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_09)
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .dynamic(.Neutral_08)

        setupViews()

        [unreadMarker, avatarView, stackView, insertedAtLabel, bottomStroke].forEach(contentView.addSubview)

        unreadMarker.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.equalToSuperview().inset(8)
            make.width.height.equalTo(8)
        }

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalToSuperview().inset(18)
            make.width.height.equalTo(32)
        }

        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(58)
            make.top.trailing.equalToSuperview().inset(12)
        }

        insertedAtLabel.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom).offset(4)
            make.leading.equalToSuperview().inset(58)
            make.bottom.trailing.equalToSuperview().inset(12)
        }

        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        unreadMarker.backgroundColor = .Special_01
        unreadMarker.layer.cornerRadius = 4
        unreadMarker.isHidden = true

        avatarView.backgroundColor = .dynamic(.Neutral_08)
        avatarView.layer.cornerRadius = 16
        avatarView.isHidden = true

        stackView.axis = .vertical
        stackView.spacing = 4

        insertedAtLabel.font = .preferredFont(forTextStyle: .footnote)
        insertedAtLabel.textColor = .dynamic(.Neutral_05)
        insertedAtLabel.adjustsFontForContentSizeCategory = true

        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    func setFeedItem(_ item: Knock.FeedItem) {
        unreadMarker.isHidden = item.read_at != nil
        avatarView.isHidden = false
        if let parsedBody = item.data?["parsedBody"]?.value as? [(Knock.FeedItem.ParsedBodyClass, String)] {
            parsedBody.forEach { bodyElem in
                if variant == .project, bodyElem.0 == .project {
                    // don't show project info when viewing project in app feed
                    return
                }
                stackView.addArrangedSubview(getView(forParsedBodyClass: bodyElem.0, text: bodyElem.1))
            }
        }
        insertedAtLabel.text = if let inserted_at = item.inserted_at { Date.format1Ago(inserted_at) } else { "" }
    }

    private func getView(forParsedBodyClass bodyClass: Knock.FeedItem.ParsedBodyClass, text: String) -> UIView {
        switch bodyClass {
        case .project, .subject:
            return createViewForProjectClass(text)
        case .label:
            return createViewForLabelClass(text)
        case .message:
            return createViewForMessageClass(text)
        }
    }

    private func createViewForProjectClass(_ text: String) -> UIView {
        let label = UILabel()
        label.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        label.textColor = .dynamic(.Neutral_05)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        return label
    }

    private func createViewForLabelClass(_ text: String) -> UIView {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .dynamic(.Neutral_04)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        return label
    }

    private func createViewForMessageClass(_ text: String) -> UIView {
        // we need a view with a line on the left and text next to it
        let wrapper = UIView()

        let blockquote = UIView()
        blockquote.backgroundColor = .dynamic(.Neutral_06)
        blockquote.layer.cornerRadius = 1.5
        wrapper.addSubview(blockquote)
        blockquote.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.width.equalTo(3)
        }

        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .dynamic(.Neutral_04)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        wrapper.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.equalToSuperview().inset(8)
        }
        return wrapper
    }

    override func prepareForReuse() {
        unreadMarker.isHidden = true
        avatarView.isHidden = true
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        insertedAtLabel.text = ""
    }
}
