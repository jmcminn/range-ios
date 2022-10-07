import Foundation
import SnapKit
import UIKit

/// The view controller for searching the tags, showing selected tags in horizontal collection, and showing tags table for tags selection
/// It operates on TagsViewModel
/// Uses `SearchAndSelectTagsHeaderViewController` for search  + selected tags  and
/// `TagsSelectionViewController` for selecting tags
class SearchAndSelectTagsViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    /// tags to edit
    var tagsViewModel: TagsViewModel

    /// container for the title and close button. We need separate view displayed on top of contentView to cover the top shadow
    /// from the tagsHeaderVC
    var topBarView = UIView()
    var closeButton: UIButton!
    var titleIcon: UIImageView!
    var titleLabel: UILabel!
    /// view for tags header and tags selection table
    let contentView = UIView()

    /// Header with search and selected tags
    var tagsHeaderVC: SearchAndSelectTagsHeaderViewController!
    var tagsHeaderViewHeightConstraint: Constraint?

    /// tags table view showing all project tags, popular and recent
    var tagsVC: TagsSelectionViewController!

    /// Header expander that shows/hides the search view in tags header
    var tagsHeaderExpander: HeaderExpander!

    var onClose: (() -> Void)?

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    init(tagsViewModel: TagsViewModel) {
        self.tagsViewModel = tagsViewModel
        super.init(nibName: nil, bundle: nil)

        tagsViewModel.addDelegate(self)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        topBarView.backgroundColor = containerView.backgroundColor
        containerView.addSubview(topBarView)
        topBarView.snp.makeConstraints { make in
            make.height.equalTo(67)
            make.top.left.right.equalToSuperview()
        }

        topBarView.installSliderView()

        setupCloseButton()
        topBarView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(21)
        }

        setupTitle()
        topBarView.addSubview(titleIcon)
        topBarView.addSubview(titleLabel)
        titleIcon.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton.snp.centerY)
            make.leading.equalTo(16)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton.snp.centerY)
            make.leading.equalTo(titleIcon.snp.trailing).offset(8)
        }

        contentView.backgroundColor = containerView.backgroundColor
        containerView.insertSubview(contentView, belowSubview: topBarView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(67)
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        // stroke not visible in dark mode (same color as background)
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_10 : .Neutral_04
    }
}

// MARK: Views

extension SearchAndSelectTagsViewController {
    private func setupTitle() {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        let image = UIImage(systemName: "tag", withConfiguration: imageConfig)
        titleIcon = UIImageView(image: image)
        titleIcon.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)

        titleLabel = UILabel()
        titleLabel.text = "Tags"
        titleLabel.textColor = titleIcon.tintColor
        titleLabel.font = UIFont._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
    }

    private func setupCloseButton() {
        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.onClose?()
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupTagsHeaderView() {
        tagsHeaderVC = SearchAndSelectTagsHeaderViewController(viewModel: tagsViewModel)
        tagsHeaderVC.searchView.textField.returnKeyType = .done
    }

    private func setupTagsView() {
        tagsVC = TagsSelectionViewController(viewModel: tagsViewModel)
        tagsVC.tableView.contentInsetAdjustmentBehavior = .never
        tagsVC.tableView.forwardDelegateInvocations(to: self)
        tagsVC.tableView.keyboardDismissMode = .onDrag
    }
}

/// SearchAndSelectTagsViewController is a CardPresentable, but of a fixed size never partially-open
extension SearchAndSelectTagsViewController: CardPresentable {
    func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        // the card display controller adds handling for bottom safe area so we need to subtract it
        // also we don't want to cover the top safe area
        let fullHeight = cardContainerView.bounds.height - cardContainerView.safeAreaInsets.bottom - cardContainerView
            .safeAreaInsets.top
        return fullHeight
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

// MARK: - tags table scroll view delegate

extension SearchAndSelectTagsViewController: UIScrollViewDelegate {
    /// on tags scroll adjust the header bottom stroke visibility
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        tagsHeaderVC.bottomStrokeVisible = scrollView.contentOffset.y > 0
    }
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

        if selected {
            // showing the tags
            tagsHeaderVC.selectedTagsWillShow()
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
            // hiding the tags
            tagsHeaderVC.selectedTagsWillHide()
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
