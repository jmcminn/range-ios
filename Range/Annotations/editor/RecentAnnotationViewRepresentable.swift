import Foundation
import SwiftUI

/// Provides annotations rendering for SwiftUI (so we can render the annotations when displaying in RecentAnnotationsSelectorView)
/// Assumes that the TextAnnotation is unscaled and renders with the font size provided in the annotation
struct RecentAnnotationViewRepresentable: UIViewRepresentable {
    let view: AnnotationReadonlyView

    init(textAnnotation: TextAnnotation) {
        view = AnnotationReadonlyView(textAnnotation: textAnnotation)
    }

    func makeUIView(context _: Context) -> AnnotationReadonlyView {
        view
    }

    func updateUIView(_: AnnotationReadonlyView, context _: Context) {}
}

/// UIView that renders given annotation using its Renderer. The annotation is not rendered in the image context, so it's unscaled
class AnnotationReadonlyView: UIView {
    // unscaled annotation font size as we're rendering in UIView that is not scaled
    private var fontSize: Double { UIFont.preferredFont(forTextStyle: .body).lineHeight }
    private var annotationSize: CGSize = .zero
    let annotation: TextAnnotation
    override var intrinsicContentSize: CGSize { annotationSize }

    init(textAnnotation: TextAnnotation) {
        annotation = textAnnotation
        super.init(frame: .zero)

        updateAnnotationSize()
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateAnnotationSize()
    }

    private func updateAnnotationSize() {
        annotationSize = TextAnnotationRenderer.annotationSize(
            text: annotation.text,
            fontSize: fontSize,
            annotationScale: 1
        )
        invalidateIntrinsicContentSize()
    }

    override func draw(_: CGRect) {
        TextAnnotationRenderer.render(
            text: annotation.text,
            position: .zero,
            fontSize: fontSize,
            color: annotation.color,
            annotationScale: 1,
            backgroundOnly: false,
            renderShadow: false
        )
    }
}
