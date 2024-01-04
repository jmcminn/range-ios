import Foundation
import SwiftUI
import UIKit

struct RepresentedSearchView: UIViewRepresentable {
    typealias UIViewType = SearchView
    @Binding var text: String
    private var onActivated: (() -> Void)?
    private var placeholder = ""

    init(text: Binding<String>, onActivated: (() -> Void)?) {
        _text = text
        self.onActivated = onActivated
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
        Coordinator(text: $text, onActivated: onActivated)
    }

    class Coordinator: NSObject, SearchViewDelegate {
        @Binding var text: String
        private var onActivated: (() -> Void)?

        init(text: Binding<String>, onActivated: (() -> Void)?) {
            _text = text
            self.onActivated = onActivated
        }

        func searchView(_: SearchView, textDidChange text: String) {
            self.text = text
        }

        func searchViewActivated(_: SearchView) {
            // user started editing the text
            onActivated?()
        }
    }

    func placeholder(_ string: String) -> RepresentedSearchView {
        var view = self
        view.placeholder = string
        return view
    }
}
