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
    let fontSize: Double
    let annotationSize: CGSize
    let annotation: TextAnnotation
    override var intrinsicContentSize: CGSize { annotationSize }

    init(textAnnotation: TextAnnotation) {
        fontSize = if let fontSize = textAnnotation.fontSizeEnum(1) { fontSize.toolbarSize }
        else { textAnnotation.fontSize }

        annotationSize = TextAnnotationRenderer.annotationSize(
            text: textAnnotation.text,
            fontSize: fontSize,
            annotationScale: 1
        )
        annotation = textAnnotation
        super.init(frame: .zero)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
