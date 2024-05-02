import Combine
import Foundation
import UIKit

/// View to render the text annotation.
/// It also allows for editing of text annotations (when in editing mode it shows a UITextView to allow for text input)
/// Please note that unlike ScribblingView this view is not transformed, so it is displayed as is, without downscaling using annotationsScale
class TextAnnotationView: UIView {
    let viewModel: TextAnnotationViewModel
    // A separate view with shadow is needed because of custom draw function
    // A) draw cannot draw outside of view bounds, so cannot draw shadow
    // B) this view cannot have rounded corners because of draw, so its shadow cannot have rounded corners...
    let backgroundShadowView = UIView()
    let selectedLayer = CAShapeLayer()

    var textEditingView: UITextView?

    let textViewInputAccessoryView: UIView

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: TextAnnotationViewModel, inputAccessoryView: UIView) {
        self.viewModel = viewModel
        textViewInputAccessoryView = inputAccessoryView
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = false
        setupBackgroundShadowView()
        setupSelectedLayer()
        updateSelectedLayer()
        setSelected(viewModel.selected)

        viewModel.text.$color.sink { [weak self] _ in
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

        viewModel.$textEditing.sink { [weak self] textEditing in
            self?.setTextEditing(textEditing)
            self?.setNeedsLayout()
            self?.setNeedsDisplay()
        }.store(in: &subscriptions)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBackgroundShadowView() {
        setShadowWithFigmaValues(x: 0, y: 2, blur: 8, opacity: 0.25)
        addSubview(backgroundShadowView)
        backgroundShadowView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupSelectedLayer() {
        selectedLayer.strokeColor = UIColor.Primary_Blue_04.cgColor
        selectedLayer.fillColor = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = Annotations.textBoxCornerRadius(forFontSize: viewModel.text.fontSize)
        backgroundShadowView.layer.cornerRadius = cornerRadius
        layer.cornerRadius = cornerRadius
        updateSelectedLayer()
        updateTextEditingView()
    }

    private func setSelected(_ selected: Bool) {
        isUserInteractionEnabled = selected
    }

    // Insert text at cursor or replace the current selection
    func insertText(_ text: String) {
        guard let textView = textEditingView else { return }
        if let selectedTextRange = textView.selectedTextRange {
            textView.replace(selectedTextRange, withText: text)
        } else {
            textView.insertText(text)
        }
    }

    private func setTextEditing(_ textEditing: Bool) {
        if textEditing {
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
        textView.inputAccessoryView = textViewInputAccessoryView
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
        let textHorizontalPadding = ceil(Annotations.textHorizontalPadding(forFontSize: viewModel.text.fontSize))
        let textVerticalPadding = ceil(Annotations.textVerticalPadding(forFontSize: viewModel.text.fontSize))
        textEditingView.snp.remakeConstraints { make in
            make.top.equalToSuperview().inset(textVerticalPadding)
            make.leading.equalToSuperview().inset(textHorizontalPadding)
            make.width.equalTo(viewModel.viewFrame.width - 2 * textHorizontalPadding)
            make.height.equalTo(viewModel.viewFrame.height - 2 * textVerticalPadding)
        }
    }

    private func updateSelectedLayer() {
        if viewModel.selected {
            var selectionFrame = bounds
            // if text is editing then we show the selection with some minimal width (so the initial
            // empty text annotation selection is centered horizontally on the screen and allows
            // for some text growth before the selection border grows)
            if viewModel.textEditing {
                selectionFrame.size.width = max(
                    selectionFrame.width,
                    TextAnnotationRenderer.emptyTextBoxWidth * viewModel.annotationsGeometry.scale
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
                cornerRadius: Annotations.textBoxCornerRadius(forFontSize: viewModel.text.fontSize)
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
            annotationScale: viewModel.annotationsGeometry.scale,
            backgroundOnly: viewModel.textEditing, // when editing the text is rendered with UITextView (to edit)
            renderShadow: false,
            // the shadow is added using backgroundShadowView (otherwise would be clipped to bounds)
            renderingOffset: viewModel.text.position.multiplyBy(-1) // rendering in view coordinates
        )
    }
}

extension TextAnnotationView: UITextViewDelegate {
    /// Update the view model with any text view updates (text changes). This will trigger recalculating the viewFrame which will
    /// cause the view to update the annotation box
    func textViewDidChange(_ textView: UITextView) {
        viewModel.setText(textView.text)
    }
}
