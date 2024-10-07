import SnapKit
import SwiftUI
import UIKit

/// A tooltip view with a text description
class MapTooltipView: UIView {
    enum ArrowPosition {
        case bottom
        case right
    }

    init(text: String, boxColor: UIColor, arrowPosition: ArrowPosition = .bottom) {
        super.init(frame: .zero)

        /// box is just a view with rounded corners
        let boxView = UIView()
        boxView.backgroundColor = boxColor
        boxView.layer.cornerRadius = 10
        boxView.layer.borderWidth = 1
        boxView.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
        boxView.layer.shadowColor = UIColor.black.cgColor // always black, since "map" is always light?
        boxView.setShadowWithFigmaValues(y: 6, blur: 10, opacity: 0.2)
        addSubview(boxView)

        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        let textLabel = UILabel()
        textLabel.text = text
        textLabel.textColor = .Neutral_01
        textLabel.font = boldFont
        textLabel.adjustsFontForContentSizeCategory = true
        addSubview(textLabel)

        // the arrow view has a custom shape from figma, exported as tooltip_arrow to be used with tint color
        // and a separate tooltip_arrow_border to add the border at the bottom of the arrow
        let arrowView = UIImageView(image: UIImage(named: "tooltip_arrow")?.withTintColor(boxColor))
        arrowView.setShadowWithFigmaValues(y: 6, blur: 10, opacity: 0.2)
        arrowView.layer.shadowColor = UIColor.black.cgColor // always black, since "map" is always light?
        addSubview(arrowView)

        let arrowBorderView = UIImageView(image: UIImage(named: "tooltip_arrow_border"))
        arrowView.addSubview(arrowBorderView)
        arrowBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if arrowPosition == .bottom {
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
        } else {
            arrowView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
            textLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 13, bottom: 12, right: 23))
            }
            boxView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10))
            }
            arrowView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalTo(boxView.snp.right)
                    .offset(-6) // -1 to cover the border, -5 for the rotation (it's 20x10, and the layout doesn't know about rotation making it 10x20)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
