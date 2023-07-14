import Foundation
import UIKit

class ScribbleView: UIView {
    let viewModel: ScribbleViewModel
    private var scribbleObservation: NSKeyValueObservation?
    private var viewBoundsObservation: NSKeyValueObservation?
    private var zoomScaleObservation: NSKeyValueObservation?
    private var selectedObservation: NSKeyValueObservation?

    init(viewModel: ScribbleViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.borderColor = UIColor.Primary_Blue_04.cgColor
        updateBorderWidth()
        transform = CGAffineTransform(scaleX: viewModel.scale, y: viewModel.scale)
        scribbleObservation = viewModel.scribble.observe(\.color, changeHandler: { [weak self] _, _ in
            self?.setNeedsDisplay()
        })
        viewBoundsObservation = viewModel.observe(\.viewBounds) { [weak self] _, _ in
            self?.frame = viewModel.viewBounds
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
            layer.borderWidth = 2 / viewModel.scale / viewModel.zoomScale
        } else {
            layer.borderWidth = 0
        }
        setNeedsDisplay()
    }

    override func draw(_: CGRect) {
        let path = viewModel.uiPath
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        // lineWidth needs no scaling as the whole view is scaled
        let lineWidth = viewModel.scribble.lineWidth / viewModel.scale

        // outline
        path.lineWidth = 2 * lineWidth
        UIColor.white.set()
        path.stroke()

        // line
        path.lineWidth = lineWidth
        viewModel.scribble.color.set()
        path.stroke()
    }
}
