import Combine
import Foundation
import UIKit

class ScribbleAnnotationView: UIView {
    let viewModel: ScribbleAnnotationViewModel

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

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
        setSelected(viewModel.selected)

        viewModel.scribble.$color.sink { [weak self] _ in
            self?.setNeedsDisplay()
        }.store(in: &subscriptions)

        viewModel.$viewFrame.sink { [weak self] frame in
            self?.frame = frame
            self?.setNeedsLayout()
            self?.setNeedsDisplay()
        }.store(in: &subscriptions)

        viewModel.$zoomScale.sink { [weak self] _ in
            self?.setNeedsLayout()
            self?.setNeedsDisplay()
        }.store(in: &subscriptions)

        viewModel.$selected.sink { [weak self] selected in
            self?.setSelected(selected)
            self?.setNeedsLayout()
            self?.setNeedsDisplay()
        }.store(in: &subscriptions)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setSelected(_ selected: Bool) {
        isUserInteractionEnabled = selected
    }

    override func layoutSubviews() {
        super.layoutSubviews()

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

    override func draw(_: CGRect) {
        // lineWidth needs "unscaling" as the whole view is scaled
        let lineWidth = viewModel.scribble.lineWidth / viewModel.annotationsGeometry.scale

        ScribbleAnnotationRenderer.render(path: viewModel.uiPath, lineWidth: lineWidth, color: viewModel.scribble.color)
    }
}
