import Foundation
import UIKit

/// A subclass of SearchView that is specialized for working on `TagsViewModel`
/// It updates the view model filter when the text changes and handles they keyboard return button by creating a new tag.
class TagsSearchView: SearchView {
    unowned let viewModel: TagsViewModel

    init(placeholderText: String, viewModel: TagsViewModel) {
        self.viewModel = viewModel
        super.init(placeholderText: placeholderText)

        addDelegate(self)
    }
}

extension TagsSearchView: SearchViewDelegate {
    func searchView(_: SearchView, textDidChange text: String) {
        viewModel.filter(by: text)
    }

    func searchViewReturnButtonTapped(_ searchView: SearchView) {
        // if the filter is entered and the only option is to add new tag - add it
        if !viewModel.filterStringTrimmed.isEmpty, viewModel.filteredTags.isEmpty {
            let tag = TagViewModel(newTagWithName: viewModel.filterStringTrimmed)
            viewModel.add(tag: tag)
            viewModel.set(tagWithId: tag.id, selected: true)
            viewModel.filter(by: "")
        }
        searchView.endEditing(true)
    }
}
