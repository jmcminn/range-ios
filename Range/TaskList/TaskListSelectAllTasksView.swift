import Foundation
import UIKit

/// The view with a checkmark to select all task in Task list
class TaskListSelectAllTasksView: UIView {
    private let selectedView = UIImageView()
    private let titleLabel = UILabel()
    private let bottomStroke = UIView()

    init() {
        super.init(frame: .zero)
        backgroundColor = .dynamic(.Neutral_10)

        setupTitleLabel()
        setupSelectionViews()
        setupBottomStroke()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTitleLabel() {
        titleLabel.text = String(localized: "Select All Tasks")
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .dynamic(.Neutral_04)
        titleLabel.adjustsFontForContentSizeCategory = true
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(10)
            make.leading.equalToSuperview().inset(64)
            make.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupSelectionViews() {
        let selectBackground = UIView()
        selectBackground.backgroundColor = .dynamic(.Neutral_09)
        addSubview(selectBackground)
        selectBackground.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(48)
        }

        selectedView.tintColor = .dynamic(.Neutral_04)
        selectBackground.addSubview(selectedView)
        selectedView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        mark(selected: false)
    }

    private func setupBottomStroke() {
        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
        addSubview(bottomStroke)
        bottomStroke.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.left.right.bottom.equalToSuperview()
        }
    }

    func mark(selected: Bool) {
        selectedView.image = selected
            ? UIImage(named: "checkmark_checked")
            : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                            bgColor: .dynamic(.Neutral_10),
                                            strokeColor: .dynamic(.Neutral_07))
    }
}
