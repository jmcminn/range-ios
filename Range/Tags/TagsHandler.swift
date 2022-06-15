import Foundation
import UIKit

// TODO: 72 reload the tags when new one added
// TODO: 72 update docs
/// TagsHandler coordinates  between tags `SearchView`, `SelectedTagsViewController` and `TagsViewController`
/// It is (will be) responsible for switching the tags between search mode and normal all tags mode when user enters terms into search
/// view
class TagsHandler: NSObject {
    unowned let viewModel: TagsViewModel
    unowned let searchView: SearchView
    unowned let selectedTagsVC: SelectedTagsViewController
    unowned let tagsVC: TagsViewController

    /// - Parameters:
    ///     - viewModel: tags view model
    ///     - searchView: input for searching
    ///     - selectedTagsVC: vc showing the currently selected tags
    ///     - tagsVC: view controller showing the list of tags for selection and search results when in search mode
    init(
        viewModel: TagsViewModel,
        searchView: SearchView,
        selectedTagsVC: SelectedTagsViewController,
        tagsVC: TagsViewController
    ) {
        self.viewModel = viewModel
        self.searchView = searchView
        self.selectedTagsVC = selectedTagsVC
        self.tagsVC = tagsVC
        super.init()

        searchView.addDelegate(self)
        tagsVC.tableView.forwardDelegateInvocations(to: self)
    }
}

// MARK: - search view handling

extension TagsHandler: SearchViewDelegate {
    func searchViewActivated(_: SearchView) {}
}

// MARK: - tags table hanling

extension TagsHandler: UIScrollViewDelegate {
    /// on tags scroll end the editing (hide keyboard for the search view)
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === tagsVC.tableView {
            searchView.endEditing(true)
        }
    }
}
