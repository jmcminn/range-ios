import Foundation
import UIKit

/// Table view cell for displaying ProjectSummary
class ProjectTableViewCell: UITableViewCell {
    private let idLabel = UILabel()
    private let nameLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let addressLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()

        [idLabel, nameLabel, descriptionLabel, addressLabel].forEach(contentView.addSubview)

        idLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
            make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
            make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(nameLabel)
        }
        addressLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(nameLabel)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        idLabel.textColor = .dynamic(.Neutral_05)
        idLabel.font = .preferredFont(forTextStyle: .footnote)
        idLabel.adjustsFontForContentSizeCategory = true

        nameLabel.numberOfLines = 0
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)

        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .dynamic(.Neutral_05)
        descriptionLabel.font = .preferredFont(forTextStyle: .footnote)

        addressLabel.numberOfLines = 0
        addressLabel.textColor = .dynamic(.Neutral_05)
        addressLabel.font = .preferredFont(forTextStyle: .footnote)
    }

    func setProject(_ project: ProjectSummary) {
        guard !project.isInvalidated else { return }
        if let identifier = project.identifier {
            idLabel.text = "ID: \(identifier)"
            idLabel.isHidden = false
            nameLabel.snp.remakeConstraints { make in
                make.top.equalTo(idLabel.snp.bottom).offset(2)
                make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
                make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
            }
        } else {
            idLabel.text = nil
            idLabel.isHidden = true
            nameLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().inset(16)
                make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
                make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
            }
        }
        nameLabel.text = project.name
        descriptionLabel.text = project.projectDescription

        let addressString = NSMutableAttributedString()
        if let pinImage = UIImage(systemName: "pin") {
            let pinAttachment = NSTextAttachment(image: pinImage)
            addressString.append(NSAttributedString(attachment: pinAttachment))
            addressString.append(NSAttributedString(string: " "))
        }
        if let address = project.address {
            addressString.append(NSAttributedString(string: address))
        }
        addressLabel.attributedText = addressString
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        descriptionLabel.text = nil
        addressLabel.attributedText = nil
    }
}
