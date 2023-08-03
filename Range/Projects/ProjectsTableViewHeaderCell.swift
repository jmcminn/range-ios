import Foundation
import UIKit

/// Table view cell for displaying projects header view
class ProjectTableViewHeaderCell: UITableViewCell {
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear
        selectionStyle = .none

        setupViews()

        contentView.addSubview(nameLabel)

        nameLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(contentView.snp.leadingMargin)
            make.trailing.equalTo(contentView.snp.trailingMargin)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        nameLabel.numberOfLines = 0
        nameLabel.textColor = .dynamic(.Neutral_05)
        nameLabel.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
    }

    func setName(_ name: String) {
        nameLabel.text = name
    }

    override func prepareForReuse() {
        nameLabel.text = nil
    }
}
