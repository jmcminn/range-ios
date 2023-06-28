import SwiftUI

/// Wraps UIVisualEffectView into a SwiftUI view
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context _: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context _: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}
