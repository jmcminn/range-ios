import Foundation
import UIKit

class ScribbleAnnotationView: UIView {
    let viewModel: ScribbleAnnotationViewModel
    private var scribbleObservation: NSKeyValueObservation?
    private var viewFrameObservation: NSKeyValueObservation?
    private var zoomScaleObservation: NSKeyValueObservation?
    private var selectedObservation: NSKeyValueObservation?

    init(viewModel: ScribbleAnnotationViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.borderColor = UIColor.Primary_Blue_04.cgColor
        updateBorderWidth()
        transform = CGAffineTransform(
            scaleX: viewModel.annotationsGeometry.scale,
            y: viewModel.annotationsGeometry.scale
        )
        scribbleObservation = viewModel.scribble.observe(\.color, changeHandler: { [weak self] _, _ in
            self?.setNeedsDisplay()
        })
        viewFrameObservation = viewModel.observe(\.viewFrame) { [weak self] _, _ in
            self?.frame = viewModel.viewFrame
            self?.setNeedsLayout()
            self?.setNeedsDisplay()
        }
        zoomScaleObservation = viewModel.observe(\.zoomScale) { [weak self] _, _ in
            self?.updateBorderWidth()
        }
        selectedObservation = viewModel.observe(\.selected) { [weak self] _, _ in
            self?.onSelectedUpdate()
        }

        onSelectedUpdate()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func onSelectedUpdate() {
        isUserInteractionEnabled = viewModel.selected
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
        setNeedsDisplay()
    }

    override func draw(_: CGRect) {
        // lineWidth needs "unscaling" as the whole view is scaled
        let lineWidth = viewModel.scribble.lineWidth / viewModel.annotationsGeometry.scale

        ScribbleAnnotationRenderer.render(path: viewModel.uiPath, lineWidth: lineWidth, color: viewModel.scribble.color)
    }
}
