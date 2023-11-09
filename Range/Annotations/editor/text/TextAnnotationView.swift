import Foundation
import UIKit

/// View to render the text annotation.
/// It also allows for editing of text annotations (when in editing mode it shows a UITextView to allow for text input)
/// Please note that unlike ScribblingView this view is not transformed, so it is displayed as is, without downscaling using annotationsScale
class TextAnnotationView: UIView {
    let viewModel: TextAnnotationViewModel
    private var annotationObservation: NSKeyValueObservation?
    private var viewFrameObservation: NSKeyValueObservation?
    private var zoomScaleObservation: NSKeyValueObservation?
    private var selectedObservation: NSKeyValueObservation?
    private var textEditingObservation: NSKeyValueObservation?
    let selectedLayer = CAShapeLayer()
    var textEditingView: UITextView?

    init(viewModel: TextAnnotationViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        backgroundColor = .clear
        setupSelectedLayer()
        updateSelectedLayer()
        annotationObservation = viewModel.text.observe(\.color, changeHandler: { [weak self] _, _ in
            self?.setNeedsDisplay()
        })
        viewFrameObservation = viewModel.observe(\.viewFrame) { [weak self] _, _ in
            self?.frame = viewModel.viewFrame
            self?.updateTextEditingView()
            self?.updateSelectedLayer()
            self?.setNeedsLayout()
            self?.setNeedsDisplay()
        }
        zoomScaleObservation = viewModel.observe(\.zoomScale) { [weak self] _, _ in
            self?.updateSelectedLayer()
        }
        selectedObservation = viewModel.observe(\.selected) { [weak self] _, _ in
            self?.onSelectedUpdate()
        }
        textEditingObservation = viewModel.observe(\.textEditing) { [weak self] _, _ in
            self?.onTextEditingUpdate()
        }

        onSelectedUpdate()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func onSelectedUpdate() {
        isUserInteractionEnabled = viewModel.selected
        updateSelectedLayer()
    }

    private func onTextEditingUpdate() {
        updateSelectedLayer()
        if viewModel.textEditing {
            // when editing we show the text view for user to enter the annotation text
            setupTextEditingView()
            textEditingView?.isHidden = false
            textEditingView?.becomeFirstResponder()
        } else {
            // when not editing the text view is hidden and the text annotation is fully rendered
            // by the renderer (see the `draw` function)
            textEditingView?.resignFirstResponder()
            textEditingView?.isHidden = true
        }
    }

    private func setupTextEditingView() {
        guard textEditingView == nil else { return }
        let textView = UITextViewWithNoTextPadding()
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.keyboardAppearance = .dark
        textView.inputAccessoryView = setupInputAccessoryView()
        addSubview(textView)
        textEditingView = textView
        updateTextEditingView()
    }

    private func updateTextEditingView() {
        guard let textEditingView = textEditingView else { return }
        textEditingView.text = viewModel.text.text
        textEditingView.font = TextAnnotationRenderer.annotationFont(ofSize: viewModel.text.fontSize)
        textEditingView.tintColor = viewModel.text.color
        textEditingView.textColor = viewModel.text.color
        let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * viewModel.annotationsGeometry.scale)
        let textVerticalPadding = ceil(Annotations.textVerticalPadding * viewModel.annotationsGeometry.scale)
        textEditingView.snp.remakeConstraints { make in
            make.top.equalToSuperview().inset(textVerticalPadding)
            make.leading.equalToSuperview().inset(textHorizontalPadding)
            make.width.equalTo(viewModel.viewFrame.width - 2 * textHorizontalPadding)
            make.height.equalTo(viewModel.viewFrame.height - 2 * textVerticalPadding)
        }
    }

    private func setupSelectedLayer() {
        selectedLayer.strokeColor = UIColor.Primary_Blue_04.cgColor
        selectedLayer.fillColor = nil
    }

    private func updateSelectedLayer() {
        if viewModel.selected {
            var selectionFrame = bounds
            // if  text is editing then we show the selection with some minimal width (so the initial
            // empty text annotation selection is centered horizontally on the screen and allows
            // for some text growth before the selection border grows)
            if viewModel.textEditing {
                selectionFrame.size.width = max(
                    selectionFrame.width,
                    TextAnnotationViewModel.initialBoxWidth * viewModel.annotationsGeometry.scale
                )
            }
            selectedLayer.frame = selectionFrame.insetBy(
                dx: -5 / viewModel.zoomScale,
                dy: -6 / viewModel.zoomScale
            )
            // the higher the zoom the lower the borderWidth (because zooming in will make it look bigger
            // and we want to keep the visual width = 2)
            selectedLayer.lineWidth = 2 / viewModel.zoomScale
            selectedLayer.path = UIBezierPath(
                roundedRect: selectedLayer.bounds,
                cornerRadius: Annotations.textBoxCornerRadius * viewModel.annotationsGeometry.scale
            ).cgPath
            layer.addSublayer(selectedLayer)
        } else {
            selectedLayer.removeFromSuperlayer()
        }
        setNeedsDisplay()
    }

    override func draw(_: CGRect) {
        TextAnnotationRenderer.render(
            text: viewModel.text.text,
            position: viewModel.text.position,
            fontSize: viewModel.text.fontSize,
            color: viewModel.text.color,
            annotationsGeometry: viewModel.annotationsGeometry,
            backgroundOnly: viewModel.textEditing, // when editing the text is rendered with UITextView (to edit)
            renderingOffset: viewModel.text.position.multiplyBy(-1) // rendering in view coordinates
        )
    }

    /// Create "Done" button that will be shown above the keyboard
    private func setupInputAccessoryView() -> UIView {
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.isUserInteractionEnabled = false
        // width doesn't matter, will take as much as the keyboard
        blurEffectView.frame = CGRect(x: 0, y: 0, width: 100, height: 48)

        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
        buttonConfig.baseBackgroundColor = .clear
        buttonConfig.baseForegroundColor = .white
        buttonConfig.preferredSymbolConfigurationForImage = imageConfig
        buttonConfig.imagePlacement = .leading
        buttonConfig.imagePadding = 5
        let saveTextButton = UIButton(
            configuration: buttonConfig,
            primaryAction: UIAction(title: "Save Text", image: UIImage(systemName: "checkmark")) { [weak self] _ in
                self?.endEditing(false)
            }
        )
        blurEffectView.contentView.addSubview(saveTextButton)
        saveTextButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        return blurEffectView
    }
}

extension TextAnnotationView: UITextViewDelegate {
    /// Update the view model with any text view updates (text changes). This will trigger recalculating the viewFrame which will
    /// cause the view to update the annotation box
    func textViewDidChange(_ textView: UITextView) {
        viewModel.setText(textView.text)
    }
}
