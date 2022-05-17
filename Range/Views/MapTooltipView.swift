import SnapKit
import SwiftUI
import UIKit

/// A tooltip view with a text description
class MapTooltipView: UIView {
    init(text: String) {
        super.init(frame: .zero)

        let boxView = UIImageView(image: UIImage(named: "tooltip_box"))
        boxView.addDropshadowMd02()
        boxView.layer.shadowColor = UIColor.black.cgColor // always black, since "map" is always light?
        addSubview(boxView)

        let arrowView = UIImageView(image: UIImage(named: "tooltip_arrow"))
        arrowView.addDropshadowMd02()
        arrowView.layer.shadowColor = UIColor.black.cgColor // always black, since "map" is always light?
        addSubview(arrowView)

        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        let textLabel = UILabel()
        textLabel.text = text
        textLabel.textColor = UIColor.Misc_White
        textLabel.font = boldFont
        textLabel.adjustsFontForContentSizeCategory = true
        addSubview(textLabel)

        textLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 13, bottom: 22, right: 13))
        }
        boxView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0))
        }
        arrowView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(boxView.snp.bottom).offset(-1)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
