import Foundation
import Kingfisher
import UIKit

/// collection cell for document (non-image) media
class DocumentMediaCollectionViewCell: UICollectionViewCell {
    let avatarView = UserInitialView()
    let fileTypeBox = UIView()
    let fileTypeLabel = UILabel()
    let fileNameLabel = UILabel()
    let fileSizeLabel = LabelWithTextInsets()
    private var selectedCheckmark: UIView?

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.backgroundColor = .dynamic(.Neutral_09)

        fileTypeBox.backgroundColor = .dynamic(.Neutral_10)
        fileTypeBox.layer.cornerRadius = 6
        fileTypeBox.layer.borderWidth = 1
        contentView.addSubview(fileTypeBox)
        fileTypeBox.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(10)
            make.top.bottom.equalToSuperview().inset(8)
            make.width.equalTo(41)
        }

        fileTypeLabel.textColor = .dynamic(.Neutral_05)
        fileTypeLabel.adjustsFontForContentSizeCategory = true
        fileTypeLabel.adjustsFontSizeToFitWidth = true
        fileTypeLabel.textAlignment = .center
        fileTypeLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        fileTypeBox.addSubview(fileTypeLabel)
        fileTypeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(4)
        }

        fileSizeLabel.textInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        fileSizeLabel.borderColor = .dynamic(.Neutral_07)
        fileSizeLabel.autoround = true
        fileSizeLabel.font = ._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold)
        fileSizeLabel.textColor = .dynamic(.Neutral_05)
        fileSizeLabel.adjustsFontForContentSizeCategory = true
        fileSizeLabel.backgroundColor = .dynamic(.Neutral_10)
        contentView.addSubview(fileSizeLabel)
        fileSizeLabel.snp.makeConstraints { make in
            make.leading.equalTo(fileTypeBox.snp.trailing).offset(8)
            make.bottom.equalTo(fileTypeBox).offset(-1)
        }

        fileNameLabel.textColor = .dynamic(.Neutral_04)
        fileNameLabel.adjustsFontForContentSizeCategory = true
        fileNameLabel.lineBreakMode = .byTruncatingTail
        fileNameLabel.font = ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
        contentView.addSubview(fileNameLabel)
        fileNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(fileTypeBox.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(fileTypeBox).offset(1)
        }

        avatarView.backgroundColor = .dynamic(.Neutral_10)
        avatarView.layer.borderWidth = 1
        avatarView.label.textColor = fileTypeLabel.textColor
        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(8)
        }

        mark(selected: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        avatarView.setUser(nil)
        fileTypeLabel.text = nil
        fileSizeLabel.text = nil
        fileNameLabel.text = nil
        mark(selected: false)
    }

    func setUpload(_ upload: Upload) {
        let borderColor = chooseColor(.Neutral_07).cgColor
        contentView.layer.borderColor = borderColor
        fileTypeBox.layer.borderColor = borderColor
        avatarView.layer.borderColor = borderColor
        fileTypeLabel.text = ".\(upload.fileType.rawValue.lowercased())"
        if let fileSize = upload.fileSize {
            fileSizeLabel.text = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            fileSizeLabel.isHidden = false
            fileNameLabel.snp.remakeConstraints { make in
                make.leading.equalTo(fileTypeBox.snp.trailing).offset(8)
                make.trailing.equalToSuperview().inset(12)
                make.top.equalTo(fileTypeBox).offset(1)
            }
        } else {
            fileSizeLabel.text = nil
            fileSizeLabel.isHidden = true
            fileNameLabel.snp.remakeConstraints { make in
                make.leading.equalTo(fileTypeBox.snp.trailing).offset(8)
                make.trailing.equalToSuperview().inset(12)
                make.centerY.equalToSuperview()
            }
        }
        fileNameLabel.text = upload.fileName
        avatarView.setUser(upload.author)
    }

    func mark(selected: Bool) {
        avatarView.isHidden = selected
        contentView.backgroundColor = selected ? .Primary_Blue_02 : .dynamic(.Neutral_09)

        if selected {
            setupSelectedCheckmark()
        }
        selectedCheckmark?.isHidden = !selected
    }

    private func setupSelectedCheckmark() {
        guard selectedCheckmark == nil else { return }
        let selectedCheckmark = ImageMediaCollectionViewCell.createdSelectedCheckmark()
        selectedCheckmark.layer.cornerRadius = 12
        contentView.addSubview(selectedCheckmark)
        selectedCheckmark.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(8)
            make.width.height.equalTo(24)
        }
        layoutIfNeeded()
        self.selectedCheckmark = selectedCheckmark
    }
}
