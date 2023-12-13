import SwiftUI

/// View presenting a scrollable list of recent annotations
struct RecentAnnotationsSelectorView: View {
    @ObservedObject var model: AnnotationsEditorViewModel
    @State private var contentSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Text Annotations")
                .foregroundStyle(.white)
                .font(.body.weight(.semibold))
                .padding([.horizontal, .top], 16)
            if UserDefaults.recentTextAnnotations().isEmpty {
                Text("You have no recent text annotations. Get started with some suggestions below.")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.footnote.weight(.medium))
                    .padding(.top, 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8) // 8 is already included in the scrollView content
            } else {
                Spacer(minLength: 8) // 8 is already included in the scrollView content
            }
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            UserDefaults.recentTextAnnotations(),
                            id: \.id
                        ) { annotation in
                            Button(action: { model.recentTextAnnotationSelected(annotation) }) {
                                // scroll view for each annotation as annotation might be wider than the parent view
                                ScrollView(.horizontal) {
                                    RecentAnnotationViewRepresentable(textAnnotation: annotation)
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
        .background(
            Color(.black.withAlphaComponent(0.75))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RecentAnnotationsSelectorView(model: AnnotationsEditorViewModel())
}
