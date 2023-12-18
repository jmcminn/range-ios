import Foundation
import SwiftUI
import UIKit

struct RepresentedSearchView: UIViewRepresentable {
    typealias UIViewType = SearchView
    let view = SearchView()

    func makeUIView(context _: Context) -> SearchView {
        view
    }

    func updateUIView(_: SearchView, context _: Context) {
        // Updates the state of the specified view controller with new information from SwiftUI.
    }

    func placeholder(_ string: String) -> RepresentedSearchView {
        view.placeholderText = string
        return self
    }
}
