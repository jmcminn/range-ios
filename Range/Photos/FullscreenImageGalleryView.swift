import SwiftUI

/// The SwiftUI view that hosts the image gallery and annotations toolbar
struct FullscreenImageGalleryView: View {
    @ObservedObject var annotationsEditorViewModel: AnnotationsEditorViewModel
    var imageGalleryView: FullscreenImageGalleryScrollViewRepresentable

    var body: some View {
        ZStack {
            imageGalleryView
                .ignoresSafeArea(.all)
            VStack {
                Spacer()
                AnnotationsToolbarView(model: annotationsEditorViewModel)
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
            }
        }
    }
}

struct FullscreenImageGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        FullscreenImageGalleryView(annotationsEditorViewModel: AnnotationsEditorViewModel(),
                                   imageGalleryView: FullscreenImageGalleryScrollViewRepresentable(
                                       view: UIScrollView()
                                   ))
    }
}
