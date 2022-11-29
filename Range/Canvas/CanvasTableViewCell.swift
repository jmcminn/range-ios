import Foundation
import UIKit

class CanvasTableViewCell: UITableViewCell {
    let nameLabel = UILabel()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [nameLabel, selectedIconView].forEach(contentView.addSubview)

        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(13)
            make.bottom.lessThanOrEqualToSuperview().offset(-13)
            make.leading.equalTo(contentView.snp.leadingMargin).inset(16)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(52)
        }
        selectedIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(12)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        nameLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)
    }

    func setCanvas(_ canvas: PDFCanvas, selected: Bool) {
        nameLabel.text = canvas.displayName
        selectedIconView.isHidden = !selected
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        selectedIconView.isHidden = true
    }
}
