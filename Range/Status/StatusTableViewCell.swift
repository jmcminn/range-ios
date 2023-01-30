import Foundation
import UIKit

class StatusTableViewCell: UITableViewCell {
    let statusView = StatusView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        statusView.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        statusView.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        contentView.addSubview(statusView)

        statusView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(10)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStatus(_ status: Status, selected: Bool) {
        statusView.setStatus(status, selected: selected)
    }
}
