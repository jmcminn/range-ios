import Foundation
import UIKit

/// View shown just below TopViewController to present some context information (canvas name for now)
class TopIndicatorView: UIView {
    private let label = UILabel()

    var text: String = "" {
        didSet {
            label.text = text
        }
    }

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .Neutral_10

        label.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        label.textColor = .Neutral_04
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center

        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(10)
        }
    }
}
