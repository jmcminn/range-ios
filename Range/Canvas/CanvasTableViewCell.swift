import Foundation
import UIKit

class CanvasTableViewCell: UITableViewCell {
    let nameLabel = UILabel()
    let pinkDot = UIView()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [nameLabel, pinkDot, selectedIconView].forEach(contentView.addSubview)

        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(13)
            make.bottom.lessThanOrEqualToSuperview().offset(-13)
            make.leading.equalTo(contentView.snp.leadingMargin).inset(16)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(52)
        }
        pinkDot.snp.makeConstraints { make in
            make.width.height.equalTo(8)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
        selectedIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)

        pinkDot.backgroundColor = .Pink_03
        pinkDot.layer.cornerRadius = 4
    }

    func setCanvas(_ canvas: Canvas, selected: Bool) {
        nameLabel.text = canvas.name

        selectedIconView.isHidden = !selected
        // selectedIconView is shown on top of pink dot, so do not show pink dot when the canvas is selected
        pinkDot.isHidden = selected || canvas.geometries.isEmpty
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        selectedIconView.isHidden = true
        pinkDot.isHidden = true
    }
}
