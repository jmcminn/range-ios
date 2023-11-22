import SwiftUI

/// View presenting a scrollable list of recent annotation texts as buttons
struct RecentTextSelectorView: View {
    @ObservedObject var model: AnnotationsEditorViewModel
    @State private var contentSize: CGSize = .zero

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading) {
                    ForEach(UserDefaults.recentAnnotationTexts(), id: \.self) { text in
                        Button(action: { model.recentAnnotationTextSelected(text) }) {
                            Text(text)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.white)
                                .font(.body.bold())
                        }
                        .id(text)
                        .padding(8)
                    }
                }
                .padding(8)
                .background(
                    GeometryReader { geo -> Color in
                        DispatchQueue.main.async {
                            // get the content size to adjust the scroll view frame
                            contentSize = geo.size
                        }
                        return Color.clear
                    }
                )
                .onAppear {
                    // scroll to the last item on show, as this is the most recent
                    proxy.scrollTo(UserDefaults.recentAnnotationTexts().last, anchor: .bottom)
                }
            }
        }
        // make the scroll view frame "size to fit" the content. Otherwise the scroll view would take the whole available height
        .frame(
            minWidth: 120,
            minHeight: 40,
            maxHeight: max(40, contentSize.height)
        )
        .background(
            VisualEffectView(effect: UIBlurEffect(style: .dark))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    UserDefaults.addRecentAnnotationTexts([
        .init(text: "Busted water leak", position: .zero, fontSize: 0, color: .white),
        .init(text: "Fix that", position: .zero, fontSize: 0, color: .white),
        .init(text: "Fix this", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect1", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect2", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect3", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect4", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect5", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect6", position: .zero, fontSize: 0, color: .white),
        .init(text: "Paint defect7", position: .zero, fontSize: 0, color: .white),
//        .init(text: "Paint defect\nwith new line", position: .zero, fontSize: 0, color: .white),
    ])
    return RecentTextSelectorView(model: AnnotationsEditorViewModel())
}
