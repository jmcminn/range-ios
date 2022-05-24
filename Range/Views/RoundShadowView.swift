import UIKit

/// View with top corners rounded with shadow.
/// Add subviews to the containerView!!!
/// The shadow should be added to the view itself
/// Rounded corners and a shadow cannot be on the same layer because setting the corner radius requires using a mask which would clip the shadow.
///
/// - Warning: the `topStrokeColor` needs to be manually update on user interface style change (dark/light) as it's applied as CGColor
class RoundShadowView: UIView {
    let containerView = UIView()
    let cornerRadius: CGFloat
    private var topStrokeLayer: CAShapeLayer?
    /// has to be manually updated on
    var topStrokeColor: UIColor {
        didSet {
            if let topStrokeLayer = topStrokeLayer {
                topStrokeLayer.strokeColor = topStrokeColor.cgColor
            }
        }
    }

    init(cornerRadius: CGFloat = 24.0) {
        self.cornerRadius = cornerRadius
        topStrokeColor = UIColor.clear
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
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        updateCornerPath()
    }

    private func updateCornerPath() {
        // mask
        let mask = CAShapeLayer()
        mask.path = roundedCornersPath().cgPath
        containerView.layer.mask = mask

        // stroke
        if let topStrokeLayer = topStrokeLayer {
            topStrokeLayer.removeFromSuperlayer()
        }
        let topStrokeLayer = createTopStrokeLayer()
        topStrokeLayer.strokeColor = topStrokeColor.cgColor
        topStrokeLayer.lineWidth = 1
        topStrokeLayer.fillColor = UIColor.clear.cgColor
        containerView.layer.insertSublayer(topStrokeLayer, at: 0)
        self.topStrokeLayer = topStrokeLayer
    }

    /// A layer with a path covering the top border of the view including the rounded top left and right corners
    private func createTopStrokeLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        let pathRef = CGMutablePath()

        // inset from top otherwise it's clipped, do not inset left/right, so the stroke "fades" to 0 on left/right edges
        let bounds: CGRect = bounds.inset(by: UIEdgeInsets(top: 0.5, left: 0, bottom: 0, right: 0))
        pathRef.move(to: CGPoint(x: bounds.minX, y: cornerRadius))
        pathRef.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.minY),
                       tangent2End: CGPoint(x: bounds.midX, y: bounds.minY),
                       radius: cornerRadius)

        pathRef.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.minY),
                       tangent2End: CGPoint(x: bounds.maxX, y: cornerRadius),
                       radius: cornerRadius)
        layer.path = pathRef

        return layer
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
