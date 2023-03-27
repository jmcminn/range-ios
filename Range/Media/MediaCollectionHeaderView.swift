import Foundation
import UIKit

class MediaCollectionViewHeader: UICollectionReusableView {
    static let horizontalInset = 16.0

    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)

        label.textColor = .dynamic(.Neutral_05)
        label.numberOfLines = 0
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MediaCollectionViewHeader.horizontalInset)
            make.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        label.text = nil
    }
}
