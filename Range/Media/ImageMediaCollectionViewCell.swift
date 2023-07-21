import Foundation
import Kingfisher
import UIKit

/// collection cell for image media
class ImageMediaCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)
    let avatarView = AvatarView()
    private var selectedOverlay: UIView?

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        contentView.layer.cornerRadius = 12

        contentView.addSubview(imageView)
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .dynamic(.Neutral_09)
        imageView.layer.cornerRadius = contentView.layer.cornerRadius
        imageView.clipsToBounds = true
        imageView.kf.indicatorType = .custom(indicator: ImageLoadingIndicator())
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(8)
        }

        mark(selected: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        avatarView.setUser(nil)
        mark(selected: false)
    }

    func setUpload(_ upload: Upload, imageDataProvider: RangeImageDataProvider?) {
        imageView.kf.cancelDownloadTask()
        if let imageDataProvider = imageDataProvider {
            imageView.kf.setImage(with: imageDataProvider, options: imageDataProvider.options)
        }
        avatarView.setUser(upload.author)
    }

    func mark(selected: Bool) {
        avatarView.isHidden = selected
        if selected {
            setupSelectedOverlay()
        }
        selectedOverlay?.isHidden = !selected
    }

    private func setupSelectedOverlay() {
        guard selectedOverlay == nil else { return }
        let selectedOverlay = UIView()
        selectedOverlay.backgroundColor = .Primary_Blue_02
        selectedOverlay.layer.cornerRadius = contentView.layer.cornerRadius
        contentView.addSubview(selectedOverlay)
        selectedOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let checkmarkBg = ImageMediaCollectionViewCell.createdSelectedCheckmark()
        checkmarkBg.layer.cornerRadius = 10
        selectedOverlay.addSubview(checkmarkBg)
        checkmarkBg.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(8)
            make.width.height.equalTo(20)
        }
        layoutIfNeeded()
        self.selectedOverlay = selectedOverlay
    }

    static func createdSelectedCheckmark() -> UIView {
        let checkmarkBg = UIView()
        checkmarkBg.layer.borderWidth = 1
        checkmarkBg.layer.borderColor = UIColor.Neutral_01.cgColor
        checkmarkBg.backgroundColor = .Primary_Blue_04

        let imageConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: imageConfig))
        checkmark.tintColor = .Neutral_01
        checkmarkBg.addSubview(checkmark)
        checkmark.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        return checkmarkBg
    }
}
