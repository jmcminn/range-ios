import UIKit

class PanAndZoomIndicatorView: UIView {
    init() {
        super.init(frame: .zero)

        backgroundColor = UIColor.Neutral_10
        addDropshadowMd02()
        layer.shadowColor = UIColor.black.cgColor // always black, since "map" is always light?
        layer.cornerRadius = 10

        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        let textLabel = UILabel()
        textLabel.text = "Pan and zoom to adjust the location"
        textLabel.textColor = UIColor.Neutral_01
        textLabel.font = boldFont
        textLabel.adjustsFontForContentSizeCategory = true
        addSubview(textLabel)

        textLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
