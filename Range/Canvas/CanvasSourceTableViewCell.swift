import UIKit

class CanvasSourceTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:

        iconView.tintColor = .dynamic(.Neutral_04)
        nameLabel.textColor = iconView.tintColor
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.font = .preferredFont(forTextStyle: .body)

        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)

        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalTo(contentView.snp.leadingMargin).offset(24)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(14)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(44)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCanvasSource(_ canvasSource: CanvasSource, selected: Bool) {
        nameLabel.text = canvasSource.name

        iconView.image = selected
            ? UIImage(named: "checkmark_checked")
            : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                            bgColor: .dynamic(.Neutral_10),
                                            strokeColor: .dynamic(.Neutral_07))
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        iconView.image = nil
    }
}
