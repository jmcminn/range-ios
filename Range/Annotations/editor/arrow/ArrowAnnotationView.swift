import Combine
import Foundation
import UIKit

class ArrowAnnotationView: UIView {
    private var controlPointSize = 17.0 // size of the control point in screen points

    let viewModel: ArrowAnnotationViewModel
    let arrowLayer = CAShapeLayer() // colored arrow shape
    let outlineLayer = CAShapeLayer() // the white outline for arrow (or black if arrow is white)
    let selectionLayer = CAShapeLayer() // the blue selection outer outline
    // the circular views denoting start and end points when the annotation is selected
    let controlPointViews = [UIView(), UIView()]

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: ArrowAnnotationViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        setupLayers()
        updateLayers()

        setupControlPoints()
        updateControlPoints()
        setSelected(viewModel.selected)

        viewModel.arrow.$color.sink { [weak self] _ in
            self?.setNeedsLayout()
        }.store(in: &subscriptions)

        viewModel.$viewFrame.sink { [weak self] frame in
            self?.frame = frame
            self?.setNeedsLayout()
        }.store(in: &subscriptions)

        viewModel.$zoomScale.sink { [weak self] _ in
            self?.setNeedsLayout()
        }.store(in: &subscriptions)

        viewModel.$selected.sink { [weak self] selected in
            self?.setSelected(selected)
            self?.setNeedsLayout()
        }.store(in: &subscriptions)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayers() {
        for layer in [selectionLayer, outlineLayer, arrowLayer] {
            layer.fillColor = nil
            layer.lineCap = .round
            layer.lineJoin = .round
            self.layer.addSublayer(layer)
        }
        selectionLayer.strokeColor = UIColor.Primary_Blue_03.cgColor
    }

    private func setupControlPoints() {
        for view in controlPointViews {
            view.backgroundColor = UIColor.Primary_Blue_04
            view.layer.borderColor = UIColor.white.cgColor
            view.setShadowWithFigmaValues(x: 0, y: 0, blur: 4, opacity: 0.25)
            addSubview(view)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
        updateControlPoints()
    }

    private func setSelected(_ selected: Bool) {
        isUserInteractionEnabled = selected
        for view in controlPointViews {
            view.isHidden = !selected
        }
    }

    private func updateLayers() {
        arrowLayer.lineWidth = viewModel.arrow.lineWidth
        arrowLayer.strokeColor = viewModel.arrow.color.cgColor

        outlineLayer.lineWidth = 2 * viewModel.arrow.lineWidth
        outlineLayer.strokeColor = viewModel.arrow.color.hexString == UIColor.white.hexString
            ? UIColor.black.cgColor
            : UIColor.white.cgColor

        selectionLayer.lineWidth = 2 * viewModel.arrow.lineWidth
            + Annotations.LineThickness.medium.lineWidth / viewModel.zoomScale
        selectionLayer.isHidden = !viewModel.selected

        let path = viewModel.arrowUIPath.cgPath
        for layer in [arrowLayer, outlineLayer, selectionLayer] {
            layer.frame = bounds
            layer.path = path
        }
    }

    private func updateControlPoints() {
        guard viewModel.zoomScale > 0 else { return }
        let size = controlPointSize / viewModel.zoomScale
        controlPointViews[0].frame = CGRect(
            origin: viewModel.arrow.startPoint.deltaTo(viewModel.viewFrame.origin)
                .deltaTo(CGPoint(x: size / 2, y: size / 2)),
            size: CGSize(width: size, height: size)
        )
        controlPointViews[1].frame = CGRect(
            origin: viewModel.arrow.endPoint.deltaTo(viewModel.viewFrame.origin)
                .deltaTo(CGPoint(x: size / 2, y: size / 2)),
            size: CGSize(width: size, height: size)
        )

        for view in controlPointViews {
            view.layer.cornerRadius = size / 2
            view.layer.borderWidth = 3.0 / viewModel.zoomScale
        }
    }
}
