import Combine
import Foundation
import UIKit

class ScribbleAnnotationView: UIView {
    let viewModel: ScribbleAnnotationViewModel
    let lineLayer = CAShapeLayer() // colored line shape
    let outlineLayer = CAShapeLayer() // the white outline for line (or black if line is white)

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: ScribbleAnnotationViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        layer.borderColor = UIColor.Primary_Blue_04.cgColor

        transform = CGAffineTransform(
            scaleX: viewModel.annotationsGeometry.scale,
            y: viewModel.annotationsGeometry.scale
        )

        setupLayers()
        updateLayers()
        updateBorderWidth()
        setSelected(viewModel.selected)

        viewModel.scribble.$color.sink { [weak self] _ in
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
        for layer in [outlineLayer, lineLayer] {
            layer.fillColor = nil
            layer.lineCap = .round
            layer.lineJoin = .round
            self.layer.addSublayer(layer)
        }
        outlineLayer.setShadowWithFigmaValues(
            x: 0,
            y: 2 / viewModel.annotationsGeometry.scale,
            blur: 8 / viewModel.annotationsGeometry.scale,
            opacity: 0.25
        )
    }

    private func setSelected(_ selected: Bool) {
        isUserInteractionEnabled = selected
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateLayers()
        updateBorderWidth()
    }

    private func updateBorderWidth() {
        if viewModel.selected {
            // the higher the zoom the lower the borderWidth (because zooming in will make it look bigger
            // and we want to keep the visual width = 2)
            layer.borderWidth = 2 / viewModel.annotationsGeometry.scale / viewModel.zoomScale
        } else {
            layer.borderWidth = 0
        }
    }

    private func updateLayers() {
        lineLayer.lineWidth = viewModel.scribble.lineWidth / viewModel.annotationsGeometry.scale
        lineLayer.strokeColor = viewModel.scribble.color.cgColor

        outlineLayer.lineWidth = 2 * lineLayer.lineWidth
        outlineLayer.strokeColor = viewModel.scribble.color.hexString == UIColor.white.hexString
            ? UIColor.black.cgColor
            : UIColor.white.cgColor

        let path = viewModel.uiPath.cgPath
        for layer in [lineLayer, outlineLayer] {
            layer.frame = bounds
            layer.path = path
        }
    }
}
