import SwiftUI

/// The SwiftUI view that hosts the image gallery and annotations toolbar
struct FullscreenImageGalleryView: View {
    @ObservedObject var annotationsEditorViewModel: AnnotationsEditorViewModel
    var imageGalleryView: FullscreenImageGalleryScrollViewRepresentable
    var userPreferences: UserPreferences

    var body: some View {
        ZStack {
            imageGalleryView
                .ignoresSafeArea(.all)
            if annotationsEditorViewModel.recentTextSelectorVisible {
                VStack {
                    Spacer()
                    HStack {
                        RecentTextSelectorView(model: annotationsEditorViewModel, userPreferences: userPreferences)
                            .padding(8)
                            .padding(.top, 40) // so it doesn't go over the top bar
                        Spacer()
                    }
                }
            }
            if annotationsEditorViewModel.toolbarVisible {
                VStack {
                    if annotationsEditorViewModel.recentAnnotationsSelectorVisible {
                        RecentAnnotationsSelectorView(
                            model: annotationsEditorViewModel,
                            userPreferences: userPreferences
                        )
                        .padding(16)
                        .padding(.top, 40) // so it doesn't go over the top bar
                    }
                    Spacer()
                    AnnotationsToolbarView(model: annotationsEditorViewModel)
                        .padding(EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8))
                        .animation(.default, value: annotationsEditorViewModel.toolbarVisible)
                }
            }
        }
    }
}

struct FullscreenImageGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        FullscreenImageGalleryView(
            annotationsEditorViewModel: AnnotationsEditorViewModel(userPreferences: UserPreferences(userId: "preview")),
            imageGalleryView: FullscreenImageGalleryScrollViewRepresentable(
                view: UIScrollView()
            ),
            userPreferences: UserPreferences(userId: "preview")
        )
    }
}
