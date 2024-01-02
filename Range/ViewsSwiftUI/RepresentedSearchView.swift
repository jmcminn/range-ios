import Foundation
import SwiftUI
import UIKit

struct RepresentedSearchView: UIViewRepresentable {
    @Binding var text: String
    typealias UIViewType = SearchView
    let view = SearchView()

    func makeUIView(context: Context) -> SearchView {
        view.addDelegate(context.coordinator)
        return view
    }

    func updateUIView(_: SearchView, context _: Context) {
        view.textField.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, SearchViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func searchView(_: SearchView, textDidChange text: String) {
            self.text = text
        }
    }

    func placeholder(_ string: String) -> RepresentedSearchView {
        view.placeholderText = string
        return self
    }
}
