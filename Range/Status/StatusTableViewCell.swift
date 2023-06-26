import Foundation
import UIKit

class StatusTableViewCell: UITableViewCell {
    enum Variant: String {
        case status = "StatusCell"
        case statusAndArchive = "StatusAndArchiveCell"

        static func identifier(forArchive: Bool) -> String {
            forArchive ? statusAndArchive.rawValue : status.rawValue
        }
    }

    let statusView = StatusView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        let statusAndArchive = reuseIdentifier == Variant.identifier(forArchive: true)

        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        statusView.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        statusView.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        if statusAndArchive {
            let plusLabel = UILabel()
            plusLabel.font = statusView.font
            plusLabel.textColor = .dynamic(.Neutral_01)
            plusLabel.adjustsFontForContentSizeCategory = true
            plusLabel.text = "+"

            let archiveView = StatusView()
            archiveView.font = statusView.font
            archiveView.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
            archiveView.setArchived(text: String(localized: "Archive"))

            let wrapper = UIStackView(arrangedSubviews: [statusView, plusLabel, archiveView])
            wrapper.spacing = 8
            contentView.addSubview(wrapper)
            wrapper.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.bottom.equalToSuperview().inset(10)
            }
        } else {
            contentView.addSubview(statusView)
            statusView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.bottom.equalToSuperview().inset(10)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStatus(_ statusOption: StatusPickerCardViewController.StatusOption, selected: Bool) {
        switch statusOption {
        case let .status(status):
            fallthrough
        case let .completeAndArchive(status):
            statusView.setStatus(status, selected: selected)
        }
    }
}
