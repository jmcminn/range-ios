import Foundation
import SnapKit
import UIKit

/// The view controller for searching the tags, showing selected tags in horizontal collection, and showing tags table for tags selection
/// It operates on TagsViewModel
/// Uses `SearchAndSelectTagsHeaderViewController` for search  + selected tags  and
/// `TagsSelectionViewController` for selecting tags
class SearchAndSelectTagsViewController: SheetCardViewController {
    /// tags to edit
    var tagsViewModel: TagsViewModel

    /// view for tags header and tags selection table
    let contentView = UIView()

    /// Header with search and selected tags
    var tagsHeaderVC: SearchAndSelectTagsHeaderViewController!
    var tagsHeaderViewHeightConstraint: Constraint?

    /// tags table view showing all project tags, popular and recent
    var tagsVC: TagsSelectionViewController!

    /// Header expander that shows/hides the search view in tags header
    var tagsHeaderExpander: HeaderExpander!

    /// Show a special row when there's no direct match in filtered tags
    var showCreateTag: Bool = true

    /// Show a special row (in the 1st section) that allows for selecting TagViewModel.untagged - for filtering pins that have no tags
    var showUntaggedOption: Bool = false

    /// whether to show the tag count
    var showTagCount: Bool = true

    /// - Parameters:
    ///   - tagsViewModel:
    ///   - autoDismissCard: by default the card is dismissed when closed, for dismissing manually (in response to onClose) set to false
    init(tagsViewModel: TagsViewModel, autoDismissCard: Bool = true) {
        self.tagsViewModel = tagsViewModel
        super.init(
            icon: UIImage(systemName: "tag"),
            title: String(localized: "Tags"),
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true),
            autoDismiss: autoDismissCard
        )

        tagsViewModel.addDelegate(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        contentView.backgroundColor = containerView.backgroundColor
        containerView.insertSubview(contentView, belowSubview: sheetHeaderView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }

        setupTagsHeaderView()
        add(childController: tagsHeaderVC, toView: contentView)
        tagsHeaderVC.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            self.tagsHeaderViewHeightConstraint = make.height.equalTo(tagsHeaderInputMetrics().expandedHeight)
                .constraint
        }

        setupTagsView()
        add(childController: tagsVC, toView: contentView)
        contentView.insertSubview(tagsVC.view, belowSubview: tagsHeaderVC.view)
        tagsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(tagsHeaderVC.view.snp.bottom)
            make.bottom.equalToSuperview()
        }

        tagsHeaderExpander = HeaderExpander(
            drivingScrollView: tagsVC.tableView,
            contentView: contentView
        )
        tagsHeaderExpander.delegate = self

        updateColors()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // we need the views layed out, so the metrics are calculated properly, so we activate
        // on viewDidAppear
        tagsHeaderExpander.activate(headersInputMetrics: [tagsHeaderInputMetrics()])
    }

    /// SearchAndSelectTagsViewController is a CardPresentable, but of a fixed size never partially-open
    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        // the card display controller adds handling for bottom safe area so we need to subtract it
        // also we don't want to cover the top safe area
        let fullHeight = cardContainerView.bounds.height - cardContainerView.safeAreaInsets.bottom - cardContainerView
            .safeAreaInsets.top
        return fullHeight
    }

    /// on tags scroll adjust the header bottom stroke visibility
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        tagsHeaderVC.bottomStrokeVisible = scrollView.contentOffset.y > 0
    }
}

// MARK: Views

extension SearchAndSelectTagsViewController {
    private func setupTagsHeaderView() {
        tagsHeaderVC = SearchAndSelectTagsHeaderViewController(
            viewModel: tagsViewModel,
            searchPlaceholderText: showCreateTag
                ? String(localized: "Search for, or add a tag")
                : String(localized: "Search for a tag")
        )
        tagsHeaderVC.searchView.textField.returnKeyType = .done
    }

    private func setupTagsView() {
        tagsVC = TagsSelectionViewController(viewModel: tagsViewModel, showUntaggedOption: showUntaggedOption)
        tagsVC.showCreateTag = showCreateTag
        tagsVC.showTagCount = showTagCount
        tagsVC.tableView.contentInsetAdjustmentBehavior = .never
        tagsVC.tableView.forwardDelegateInvocations(to: self)
        tagsVC.tableView.keyboardDismissMode = .onDrag
    }
}

// MARK: - header expanding

extension SearchAndSelectTagsViewController: HeaderExpanderDelegate {
    private func tagsHeaderInputMetrics() -> HeaderInputMetrics {
        tagsHeaderInputMetrics(tagsVisible: !tagsViewModel.selectedTags.isEmpty)
    }

    private func tagsHeaderInputMetrics(tagsVisible: Bool) -> HeaderInputMetrics {
        let collapsedHeight: CGFloat = tagsVisible
            ? 32 /* =selected tags height */ + 16 /* = spaceBetweenViews*/
            : 1 // leave 1 for the bottom stroke to be visible
        return HeaderInputMetrics(initialHeight: tagsHeaderVC.view.frame.height,
                                  collapsedHeight: collapsedHeight,
                                  expandedHeight: 40 /* =search */ + 16 /* = padding*/ + collapsedHeight)
    }

    /// Update headers heights when the expander notifies about change
    /// It also triggers the interactive transition from details screen to photos review if user drags down = over expands the headers
    func headerExpanderDidUpdateState(_ expander: HeaderExpander, animationDuration: TimeInterval) {
        let heights = expander.headersState.heights
        tagsHeaderViewHeightConstraint?.update(offset: heights[0])
        if animationDuration > 0 {
            UIView.animate(withDuration: animationDuration) {
                self.view.layoutIfNeeded()
            }
        }
    }

    func headerExpanderWillEndExpanding(_: HeaderExpander, withVelocity _: CGFloat) {}
}

// MARK: - tags view model delegate

extension SearchAndSelectTagsViewController: TagsViewModelDelegate {
    /// React to selected tags changes by animating in/out the selected tags in the header and updating the header expander
    func tagsViewModel(_: TagsViewModel, tag _: TagViewModel, selected: Bool, indexInSelectedTags _: Int) {
        // only handle first selected tag (show tags) or last unselected (hide tags)
        guard (selected == true && tagsViewModel.selectedTags.count == 1)
            || (selected == false && tagsViewModel.selectedTags.count == 0) else { return }

        // deactive the expander as we'll be adjusting the header heights
        tagsHeaderExpander.deactivate()

        // calculate new tags header height keeping its collapsed/expanded state
        let newTagsHeaderHeight: CGFloat
        if case .collapsed = tagsHeaderExpander.headersState.states[0] {
            newTagsHeaderHeight = tagsHeaderInputMetrics(tagsVisible: selected).collapsedHeight
        } else {
            newTagsHeaderHeight = tagsHeaderInputMetrics(tagsVisible: selected).expandedHeight
        }

        let reactivateExpander = {
            // reactivate the expander with new metrics
            self.tagsHeaderExpander
                .activate(headersInputMetrics: [self.tagsHeaderInputMetrics()])
        }

        tagsHeaderVC.selectedTagsView.visibleStateWillTransition()
        if selected {
            // showing the tags
            tagsHeaderViewHeightConstraint?.update(offset: newTagsHeaderHeight)
            // first animate the header height
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            } completion: { _ in
                // when enough room show the selected tags
                self.tagsHeaderVC.setSelectedTagsVisible(selected, animated: true)
                // and reactivate the expander as the header already has its target height
                reactivateExpander()
            }
        } else {
            // first hide the tags
            tagsHeaderVC.setSelectedTagsVisible(false, animated: true) {
                // then animate the header to its new height
                self.tagsHeaderViewHeightConstraint?.update(offset: newTagsHeaderHeight)
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    // and reactivate the expander as the header already has its target height
                    reactivateExpander()
                }
            }
        }
    }

    /// When the filter is updated on TagsViewModel update the search field (as the update might not originate from the search field)
    func tagsViewModelFiltered(_ viewModel: TagsViewModel) {
        tagsHeaderVC.searchView.textField.text = viewModel.filterString
    }
}
