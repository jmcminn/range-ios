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

    /// If provided there will be a segmented control at the top showing the provided options
    /// It doesn't collapse if content is scrolled
    private(set) var options: [ActionItem]?
    private(set) var optionsToggle: SegmentedControl?

    /// Optional description displayed below options toggle (if enabled) and above the search view
    /// It collapses when content is scrolled
    private var optionLabel: LabelWithTextInsets?
    var optionLabelTopConstraint: Constraint?

    /// Header with search and selecte d tags
    var tagsHeaderVC: SearchAndSelectTagsHeaderViewController!
    var tagsHeaderViewHeightConstraint: Constraint?

    /// tags table view showing all project tags, popular and recent
    var tagsVC: TagsSelectionViewController!

    /// Header expander that shows/hides the option label (if enabled) and search view in tags header
    var headerExpander: HeaderExpander!

    /// Show a special row when there's no direct match in filtered tags
    var showCreateTag: Bool = true

    /// Show a special row (in the 1st section) that allows for selecting TagViewModel.untagged - for filtering pins that have no tags
    var showUntaggedOption: Bool = false

    /// whether to show the tag count
    var showTagCount: Bool = true

    /// whether to show the cancel/confirm bottom bar
    var showCancelConfirmBottomBar: Bool = false
    /// Called when buttons in bottom bar are tapped
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    private var bottomBar: UIView?

    /// - Parameters:
    ///   - tagsViewModel:
    ///   - autoDismissCard: by default the card is dismissed when closed, for dismissing manually (in response to onClose) set to false
    init(tagsViewModel: TagsViewModel, autoDismissCard: Bool = true) {
        self.tagsViewModel = tagsViewModel
        super.init(
            icon: UIImage(systemName: "tag"),
            title: String(localized: "Tags"),
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: .always),
            autoDismiss: autoDismissCard
        )

        tagsViewModel.addDelegate(self)
    }

    func showOptions(_ options: [ActionItem]) {
        self.options = options
        // create option label so the text can be set even before the view is loaded
        optionLabel = LabelWithTextInsets()
    }

    /// Set new text for option label and show the label (in case it was collapsed as part of header collapsing)
    func setOptionLabel(_ text: String) {
        if headerExpander != nil {
            headerExpander.deactivate()
        }
        optionLabel?.text = text
        // reveal the option label
        optionLabelTopConstraint?.update(offset: 6)
        UIView.animate(withDuration: 0.2) {
            self.optionLabel?.alpha = 1
            self.view.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self = self else { return }
            // and reactivate the expander as the header already has its target height
            if self.headerExpander != nil {
                self.activateHeaderExpander()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if showCancelConfirmBottomBar {
            setupBottomBar()
        }

        contentView.backgroundColor = containerView.backgroundColor
        containerView.insertSubview(contentView, belowSubview: sheetHeaderView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }

        setupOptionsToggle()
        if let optionsToggle = optionsToggle {
            contentView.addSubview(optionsToggle)
            optionsToggle.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(32)
            }
            if let optionLabel = optionLabel {
                contentView.addSubview(optionLabel)
                optionLabel.snp.makeConstraints { make in
                    self.optionLabelTopConstraint = make.top.equalTo(optionsToggle.snp.bottom).offset(6).constraint
                    make.leading.trailing.equalToSuperview().inset(16)
                }
            }
        }

        setupTagsHeaderView()
        add(childController: tagsHeaderVC, toView: contentView)
        if let optionLabel = optionLabel, let optionsToggle = optionsToggle {
            // cover the space below optionsToggle, so the shadow for tags header is not visible to the top
            let shadowCoverView = UIView()
            shadowCoverView.backgroundColor = containerView.backgroundColor
            contentView.insertSubview(shadowCoverView, belowSubview: optionLabel)
            shadowCoverView.snp.makeConstraints { make in
                make.top.equalTo(optionsToggle.snp.bottom)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(optionLabel.snp.bottom).offset(6)
            }
            contentView.insertSubview(tagsHeaderVC.view, belowSubview: shadowCoverView)
        }
        tagsHeaderVC.view.snp.makeConstraints { make in
            if let optionLabel = optionLabel {
                make.top.equalTo(optionLabel.snp.bottom).offset(6)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.equalToSuperview()
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

        headerExpander = HeaderExpander(
            drivingScrollView: tagsVC.tableView,
            contentView: contentView
        )
        headerExpander.delegate = self

        updateColors()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // we need the views layed out, so the metrics are calculated properly, so we activate
        // on viewDidAppear
        activateHeaderExpander()
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
    private func setupOptionsToggle() {
        guard let options = options else { return }
        optionsToggle = SegmentedControl(items: options)

        optionLabel?.numberOfLines = 0
        optionLabel?.adjustsFontForContentSizeCategory = true
        optionLabel?.font = .preferredFont(forTextStyle: .subheadline)
        optionLabel?.textColor = .dynamic(.Neutral_05)
        optionLabel?.textInsets = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
    }

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

    private func setupBottomBar() {
        guard bottomBar == nil else { return }
        let bottomBar = UIView()
        bottomBar.backgroundColor = .dynamic(.Neutral_10)

        let stroke = UIView()
        stroke.backgroundColor = .dynamic(.Neutral_07)
        bottomBar.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        let safeAreaCover = UIView()
        safeAreaCover.backgroundColor = bottomBar.backgroundColor
        bottomBar.addSubview(safeAreaCover)

        let cancelButton = RangeButton(
            configuration: UIButton.Configuration.grayButton(),
            primaryAction: UIAction(
                title: String(localized: "Cancel")
            ) { [weak self] _ in self?.onCancel?() }
        ).withCustomRangeHighlightColor()
        let confirmButton = RangeButton(
            configuration: UIButton.Configuration.blueButton(),
            primaryAction: UIAction(
                title: String(localized: "Confirm")
            ) { [weak self] _ in self?.onConfirm?() }
        ).withCustomRangeHighlightColor()
        bottomBar.addSubview(cancelButton)
        bottomBar.addSubview(confirmButton)
        cancelButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        confirmButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cancelButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(16)
            make.trailing.equalTo(confirmButton.snp.leading).offset(-16)
            make.width.equalTo(confirmButton.snp.width)
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalToSuperview().inset(16)
        }
        containerView.addSubview(bottomBar)
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(containerView.snp.bottom)
        }
        safeAreaCover.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(bottomBar.snp.bottom)
            make.height.equalTo(self.view.safeAreaLayoutGuide.snp.height)
        }

        self.bottomBar = bottomBar
    }

    /// show or hide the bottom bar depending on tags selection
    private func updateBottomBarVisibility() {
        guard showCancelConfirmBottomBar else { return }
        let shouldHide = tagsViewModel.selectedTags.isEmpty
        if shouldHide {
            if let bottomBar = bottomBar {
                bottomBar.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalTo(bottomBar.superview!.snp.bottom)
                }
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.containerView.layoutIfNeeded()
                }
            }
            headerExpander.bottomContentEdgeInset = 0
            tagsVC.tableView.scrollIndicatorInsets = tagsVC.tableView.contentInset
        } else {
            setupBottomBar()
            if let bottomBar = bottomBar {
                bottomBar.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
                }
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.containerView.layoutIfNeeded()
                } completion: { [weak self] _ in
                    guard let self = self else { return }
                    self.headerExpander.bottomContentEdgeInset = bottomBar.frame.height
                    self.tagsVC.tableView.scrollIndicatorInsets = self.tagsVC.tableView.contentInset
                }
            }
        }
    }
}

// MARK: - header expanding

extension SearchAndSelectTagsViewController: HeaderExpanderDelegate {
    private func activateHeaderExpander() {
        if optionLabel != nil {
            headerExpander.activate(headersInputMetrics: [
                optionDescriptionInputMetrics(),
                tagsHeaderInputMetrics(),
            ])
        } else {
            headerExpander.activate(headersInputMetrics: [tagsHeaderInputMetrics()])
        }
    }

    private func optionDescriptionInputMetrics() -> HeaderInputMetrics {
        guard let optionLabel = optionLabel else {
            fatalError("optionDescriptionInputMetrics called when optionLabel is nil")
        }
        return HeaderInputMetrics(
            initialHeight: optionLabel.frame.height,
            collapsedHeight: 0,
            expandedHeight: optionLabel.frame.height
        )
    }

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
        if let optionLabel = optionLabel {
            // move the option label up if it's collapsing
            let optionLabelHeightDelta = heights[0] - expander.inputMetrics[0].expandedHeight
            // hide (by changing alpha to 0) on the distance of 12 points
            optionLabel.alpha = min(1, max(0, optionLabelHeightDelta / 12 + 1))
            optionLabelTopConstraint?.update(offset: 6 + optionLabelHeightDelta)
            tagsHeaderViewHeightConstraint?.update(offset: heights[1])
        } else {
            tagsHeaderViewHeightConstraint?.update(offset: heights[0])
        }
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
        headerExpander.deactivate()

        // calculate new tags header height keeping its collapsed/expanded state
        let newTagsHeaderHeight: CGFloat
        if case .collapsed = headerExpander.headersState.states.last {
            newTagsHeaderHeight = tagsHeaderInputMetrics(tagsVisible: selected).collapsedHeight
        } else {
            newTagsHeaderHeight = tagsHeaderInputMetrics(tagsVisible: selected).expandedHeight
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
                self.activateHeaderExpander()
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
                    self.activateHeaderExpander()
                }
            }
        }

        updateBottomBarVisibility()
    }

    /// When the filter is updated on TagsViewModel update the search field (as the update might not originate from the search field)
    func tagsViewModelFiltered(_ viewModel: TagsViewModel) {
        tagsHeaderVC.searchView.textField.text = viewModel.filterString
    }
}
