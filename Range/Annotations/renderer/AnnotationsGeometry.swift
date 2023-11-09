import Foundation

/// Describes the context in which the annotations are rendered
struct AnnotationsGeometry {
    var imageWidth: Int
    var imageHeight: Int

    /// The scale applied to annotations. See `Annotations.scale` and `AnnotationViewModel.annotationsGeometry` for
    /// description how/why it is used.
    var scale: Double
}
