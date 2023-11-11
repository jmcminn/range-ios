import Foundation
import UIKit

class ArrowAnnotationView: UIView {
    let viewModel: ArrowAnnotationViewModel
    private var colorObservation: NSKeyValueObservation?
    private var viewFrameObservation: NSKeyValueObservation?
    private var zoomScaleObservation: NSKeyValueObservation?
    private var selectedObservation: NSKeyValueObservation?
    let arrowLayer = CAShapeLayer() // colored arrow shape
    let outlineLayer = CAShapeLayer() // the white outline for arrow (or black if arrow is white)
    let selectionLayer = CAShapeLayer() // the blue selection outer outline
    // the circular views denoting start and end points when the annotation is selected
    let controlPointViews = [UIView(), UIView()]

    init(viewModel: ArrowAnnotationViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        setupLayers()
        updateLayers()

        setupControlPoints()
        updateControlPoints()

        onSelectedUpdate()

        colorObservation = viewModel.arrow.observe(\.color, changeHandler: { [weak self] _, _ in
            self?.updateLayers()
        })
        viewFrameObservation = viewModel.observe(\.viewFrame) { [weak self] _, _ in
            self?.frame = viewModel.viewFrame
            self?.updateLayers()
            self?.updateControlPoints()
        }
        zoomScaleObservation = viewModel.observe(\.zoomScale) { [weak self] _, _ in
            self?.updateLayers()
            self?.updateControlPoints()
        }
        selectedObservation = viewModel.observe(\.selected) { [weak self] _, _ in
            self?.onSelectedUpdate()
        }

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func onSelectedUpdate() {
        isUserInteractionEnabled = viewModel.selected
        for view in controlPointViews {
            view.isHidden = !viewModel.selected
        }
        updateLayers()
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

        setNeedsLayout()
        setNeedsDisplay()
    }

    private func setupControlPoints() {
        for view in controlPointViews {
            view.backgroundColor = .white
            view.layer.borderColor = UIColor.Primary_Blue_04.cgColor
            addSubview(view)
        }
    }

    private func updateControlPoints() {
        let size = viewModel.arrow.lineWidth * 4 / 3
        controlPointViews[0].snp.remakeConstraints { make in
            make.center.equalTo(viewModel.arrow.startPoint.deltaTo(viewModel.viewFrame.origin))
            make.width.height.equalTo(size)
        }
        controlPointViews[1].snp.remakeConstraints { make in
            make.center.equalTo(viewModel.arrow.endPoint.deltaTo(viewModel.viewFrame.origin))
            make.width.height.equalTo(size)
        }

        for view in controlPointViews {
            view.layer.cornerRadius = size / 2
            view.layer.borderWidth = size / 4
        }

        setNeedsLayout()
        setNeedsDisplay()
    }
}
