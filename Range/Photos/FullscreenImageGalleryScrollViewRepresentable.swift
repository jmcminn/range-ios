import Foundation
import SwiftUI

/// Wrapper for the image gallery view (the scroll view with all the pages)
struct FullscreenImageGalleryScrollViewRepresentable: UIViewRepresentable {
    let view: UIScrollView

    init(view: UIScrollView) {
        self.view = view
    }

    func makeUIView(context _: Context) -> UIScrollView {
        view
    }

    func updateUIView(_: UIScrollView, context _: Context) {}
}
