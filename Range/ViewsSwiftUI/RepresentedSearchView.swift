import Foundation
import SwiftUI
import UIKit

struct RepresentedSearchView: UIViewRepresentable {
    typealias UIViewType = SearchView
    @Binding var text: String
    private var placeholder = ""

    init(text: Binding<String>) {
        _text = text
    }

    func makeUIView(context: Context) -> SearchView {
        let view = SearchView()
        view.addDelegate(context.coordinator)
        return view
    }

    func updateUIView(_ searchView: SearchView, context _: Context) {
        searchView.placeholderText = placeholder
        if searchView.textField.text != text {
            searchView.textField.text = text
            searchView.textField.sendActions(for: .editingChanged)
        }
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
        var view = self
        view.placeholder = string
        return view
    }
}
