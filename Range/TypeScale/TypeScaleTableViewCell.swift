import Foundation
import UIKit

/// Table cell for displaying collaboration data
class TypeScaleTableViewCell: UITableViewCell {
    private let textStyleLabel = UILabel()
    private let sampleTextLabel = UILabel()
    private let bottomStroke = UIView()

    private let textStyleWithShorterText: Set<UIFont.TextStyle> =
        .init([.headline, .title3, .title2, .title1, .largeTitle])

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_10)

        setupViews()

        [textStyleLabel, sampleTextLabel, bottomStroke].forEach(contentView.addSubview)

        textStyleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        sampleTextLabel.snp.makeConstraints { make in
            make.top.equalTo(textStyleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-12)
        }

        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        textStyleLabel.font = ._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold)
        textStyleLabel.textColor = .dynamic(.Neutral_05)
        textStyleLabel.adjustsFontForContentSizeCategory = true
        textStyleLabel.numberOfLines = 0

        sampleTextLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        sampleTextLabel.adjustsFontForContentSizeCategory = true
        sampleTextLabel.numberOfLines = 0

        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    func setTextStyle(_ textStyle: UIFont.TextStyle, bold: Bool) {
        let font = bold
            ? UIFont._preferredFont(forTextStyle: textStyle, symbolicTraits: .traitBold)
            : UIFont.preferredFont(forTextStyle: textStyle)
        let styleName = textStyle._displayName
        let size = Int(font.pointSize)
        let leading = Int(font.leading + font.lineHeight)
        let face = font.fontDescriptor.object(forKey: .face) as! String
        textStyleLabel.text = "\(styleName) • \(size)/\(leading) \(face)"

        sampleTextLabel.font = font
        sampleTextLabel.text = textStyleWithShorterText.contains(textStyle)
            ? "Front door thermal issues"
            :
            "There is a thermal issue along the corner wall in the office. You can feel air seeping through the wall plugs."
    }

    override func prepareForReuse() {
        textStyleLabel.text = nil
        sampleTextLabel.text = nil
    }
}
