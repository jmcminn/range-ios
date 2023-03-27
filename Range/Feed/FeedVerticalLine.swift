import Foundation
import UIKit

/// Dashed vertical line for the feed
class FeedVerticalLine: UIView {
    private var dashedLayer: CAShapeLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupDashedLayer()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        // only redraw if the height has changed
        guard bounds.height != dashedLayer?.frame.height else { return }

        dashedLayer?.removeFromSuperlayer()

        setupDashedLayer()
    }

    private func setupDashedLayer() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds
        shapeLayer.lineWidth = frame.width
        shapeLayer.lineDashPattern = [2.0, 2.0]

        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: bounds.width / 2, y: 0), CGPoint(x: bounds.width / 2, y: bounds.height)])
        shapeLayer.path = path
        layer.addSublayer(shapeLayer)

        dashedLayer = shapeLayer
        updateColor()
    }

    private func updateColor() {
        dashedLayer?.strokeColor = chooseColor(.Neutral_06).cgColor
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColor()
    }
}
