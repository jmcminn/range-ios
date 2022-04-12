import UIKit

/**
 View with top corners rounded with shadow.
 Add subviews to the containerView!!!

 Rounded corners and a shadow cannot be on the same layer because setting the corner radius requires using a mask which would clip the shadow.
 */
class RoundShadowView: UIView {
    let containerView = UIView()
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 24.0) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        layoutView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConstraints() {
        super.updateConstraints()
        updateCornerPath()
    }

    func layoutView() {
        // set the shadow of the view's layer
        layer.backgroundColor = UIColor.clear.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 1.0

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        updateCornerPath()
    }

    private func updateCornerPath() {
        let mask = CAShapeLayer()
        mask.path = roundedCornersPath().cgPath
        containerView.layer.mask = mask
    }

    private func roundedCornersPath() -> UIBezierPath {
        let corners = UIRectCorner([.topLeft, .topRight])
        return UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
    }
}
