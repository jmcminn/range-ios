import SwiftUI

/// View presenting a scrollable list of recent annotations
struct RecentAnnotationsSelectorView: View {
    @ObservedObject var model: AnnotationsEditorViewModel
    @State private var contentSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Text Annotations")
                .foregroundStyle(.white)
                .font(.body.bold())
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 8) // 8 is already included in the scrollView content
            ScrollView {
                ScrollViewReader { proxy in
                    if let annotationsEditor = model.annotationsEditor {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(UserDefaults.recentTextAnnotations(), id: \.id) { annotation in
                                Button(action: { model.recentTextAnnotationSelected(annotation) }) {
                                    // scroll view for each annotation as annotation might be wider than the parent view
                                    ScrollView(.horizontal) {
                                        RecentAnnotationViewRepresentable(
                                            textAnnotation: annotation,
                                            annotationsGeometry: annotationsEditor.annotationsGeometry
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                }
                                .id(annotation.id)
                            }
                        }
                        Spacer(minLength: 8).id("bottomSpacer")
                            .onAppear {
                                // scroll to the bottom of the list, last item is the most recent
                                proxy.scrollTo("bottomSpacer", anchor: .bottom)
                            }
                    }
                }
            }
        }
        .background(
            Color(.black.withAlphaComponent(0.75))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let annotationsGeometry = AnnotationsGeometry(imageWidth: 100, imageHeight: 100, scale: 2)
    UserDefaults.addRecentTextAnnotation(TextAnnotation(
        id: "1",
        text: "Fix this",
        position: .zero, // position is not relevant when rendering recent annotations list
        fontSize: Annotations.FontSize.large.size * annotationsGeometry.scale,
        color: Annotations.colors[2]
    ))
    UserDefaults.addRecentTextAnnotation(TextAnnotation(
        id: "2",
        text: "Paint defect",
        position: .zero,
        fontSize: Annotations.FontSize.small.size * annotationsGeometry.scale,
        color: Annotations.colors[3]
    ))
    return RecentAnnotationsSelectorView(model: AnnotationsEditorViewModel())
}
