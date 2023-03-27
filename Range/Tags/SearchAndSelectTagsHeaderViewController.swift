import UIKit

/// Header view for search and select tags view controller.
/// Contains a search view (`TagsSearchView`) and selected tags (`SelectedTagsViewController`) below.
/// The layout supports collapsing the search view.
class SearchAndSelectTagsHeaderViewController: UIViewController {
    /// The header can show or hide the selected tags. But for layout purposes it is important to know about 2 more states:
    /// showing and hiding which are temporary states when animating between visible and hidden
    enum TagsState {
        case visible // selected tags are shown
        case showing // selected tags are being animated in
        case hiding // selected tags are being animated out
        case hidden // selected tags are hidden
    }

    unowned let viewModel: TagsViewModel
    var searchView: TagsSearchView!
    var selectedTagsVC: SelectedTagsViewController!
    private var bottomStroke: UIView!

    /// current state of selected tags
    private var selectedTagsState: TagsState

    /// shows/hides the bottom stroke (+ the shadow)
    var bottomStrokeVisible: Bool = false {
        didSet {
            updateBottomStroke()
        }
    }

    init(viewModel: TagsViewModel) {
        self.viewModel = viewModel
        selectedTagsState = viewModel.selectedTags.isEmpty ? .hidden : .visible
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = .dynamic(.Neutral_10)
        buildViews()

        updateBottomStroke()
    }

    func selectedTagsWillShow() {
        selectedTagsState = .showing
    }

    func selectedTagsWillHide() {
        selectedTagsState = .hiding
    }

    /// animate the change in header height to show/hide the selected tags
    func setSelectedTagsVisible(_ visible: Bool,
                                animated: Bool = true,
                                completion: (() -> Void)? = nil)
    {
        // only animate if it's not visible and showing or visible and hiding
        guard (visible == true && selectedTagsState != .visible) ||
            (visible == false && selectedTagsState != .hidden) else { return }

        selectedTagsVC.view.isHidden = false
        if visible {
            selectedTagsVC.view.alpha = 0.0 // prepare for show
        } else {
            selectedTagsVC.view.alpha = 1.0 // prepare for hide
        }
        updateSearchViewFrame()
        let applyChange = {
            self.selectedTagsVC.view.alpha = visible ? 1.0 : 0.0
            self.selectedTagsVC.view.isHidden = !visible
            self.selectedTagsState = visible ? .visible : .hidden
        }
        if animated {
            UIView.animate(withDuration: 0.1) { applyChange() } completion: { _ in
                completion?()
            }
        } else {
            applyChange()
            completion?()
        }
    }

    /// Creates views, adds them to header and configure the layout
    private func buildViews() {
        buildTagsSearchView()
        buildSelectedTagsView()
        buildBottomStroke()

        view.addSubview(searchView)
        add(childController: selectedTagsVC)
        view.addSubview(bottomStroke)

        // hidden by default
        selectedTagsVC.view.isHidden = viewModel.selectedTags.isEmpty
        selectedTagsVC.view.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(48) // make this view higher than in the design to have bigger buttons
        }
        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        updateSearchViewFrame()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateSearchViewFrame()
    }

    /// manually update the search view frame as it depends on the current tags state. It's (probably) possible to implement the same
    /// thing with autolayout but why...
    private func updateSearchViewFrame() {
        let margin = 16.0
        let width = view.bounds.width
        let height = view.bounds.height

        // only if tags are hidden the search view can take the whole height
        let searchViewHeight = selectedTagsState == .hidden
            ? min(40, max(0, height - margin))
            : min(40, max(0, height - selectedTagsVC.view.frame.height - margin))

        searchView.frame = CGRect(
            x: margin,
            y: 0,
            width: max(40, width - 2 * margin),
            height: searchViewHeight
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// update colors that don't adapt automatically to appearance change
    private func updateColors() {
        updateShadow()
    }

    private func buildTagsSearchView() {
        searchView = TagsSearchView(
            placeholderText: String(localized: "Search for, or add a tag"),
            viewModel: viewModel
        )
    }

    private func buildSelectedTagsView() {
        selectedTagsVC = SelectedTagsViewController(viewModel: viewModel)
    }

    private func buildBottomStroke() {
        bottomStroke = UIView()
        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    /// update bottom stroke visibility (+ shadow)
    private func updateBottomStroke() {
        bottomStroke.isHidden = !bottomStrokeVisible
        updateShadow()
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateShadow() {
        if bottomStrokeVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                view.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                view.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            view.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                              y: view.bounds.maxY - 10,
                                                              width: view.bounds.width,
                                                              height: 10)).cgPath
        } else {
            view.layer.shadowOpacity = 0
        }
    }
}
