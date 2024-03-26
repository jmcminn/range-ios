import Foundation
import SnapKit
import UIKit

/// Photo details view controller.
/// Shows a photo and allows to switch between two modes, one for tags and one for the description.
///
/// This view support expanding headers.
/// Both tags and description have 1 header in common - `PhotoDetailsHeaderView` which shows the photo and tags/description
/// switch.
/// Additionally when showing tags there's another header shown below the main one - `PhotoDetailsTagsHeaderView`
///
/// Each mode has its own `HeaderExpander` that gets activated when switching to that mode and deactivated otherwise, so
/// there is always 1 expander controlling the current header(s) height(s).
class PhotoDetailsViewController: UIViewController {
    /// The photo
    unowned let localFiles: LocalFiles
    private let photosViewModel: PhotosToAddViewModel
    private let tagsViewModel: TagsViewModel
    private let initialDescription: String

    ///  exposed for customising by the canvas screenshot flow controller
    var backButton: UIButton!
    var backButtonLabel: String = .init(localized: "Back")
    var backButtonImage: UIImage? = UIImage(systemName: "arrow.backward")
    ///  exposed for customising by the add photo flow controller
    var nextButton: UIButton!
    var nextButtonLabel: String = .init(localized: "Next")
    var nextButtonImage: UIImage? = UIImage(systemName: "arrow.forward")

    /// The description provided by the user
    var photoDescription: String {
        descriptionView.textView.text
    }

    /// The mode of the PhotoDetailsViewController
    private enum Mode {
        case tags // showing tags
        case description // showing description
    }

    private var mode: Mode = .tags {
        willSet(newMode) {
            guard newMode != mode else { return }
            newModeWillSet(newMode)
        }
        didSet {
            guard mode != oldValue else { return }
            newModeDidSet()
        }
    }

    fileprivate var interactivePresentation: UIPercentDrivenInteractiveTransition?
    /// Current photo tapped (when parameter is nil) or expanded with interactive transition if provided
    var onPhotoSelected: ((UIPercentDrivenInteractiveTransition?) -> Void)?
    /// Callbacks exposed for the flow control
    var onBack: (() -> Void)?
    var onNext: (() -> Void)?

    /// vertical space between the views
    private let spaceBetweenViews = 16.0
    /// margin on the left/right
    private let horizontalMargin = 16.0

    /// the view containing the headers and scrollable content
    let contentView = UIView()

    /// header views and their updatable constraints
    var headerVC: PhotoDetailsHeaderViewController!
    var headerViewTopConstraint: Constraint?
    var headerViewHeightConstraint: Constraint?
    var tagsHeaderVC: SearchAndSelectTagsHeaderViewController!
    var tagsHeaderViewHeightConstraint: Constraint?

    var bottomBar: UIView!

    /// the content and constraints
    var tagsVC: TagsSelectionViewController!
    var descriptionView: TextView!
    var descriptionViewBottomConstraint: Constraint?

    /// tags expander - activated when mode == .tags
    var tagsHeaderExpander: HeaderExpander!
    /// description expander - activated when mode == .description
    var descriptionHeaderExpander: HeaderExpander!
    /// a convenience getter for the current expander based on the mode
    var headerExpander: HeaderExpander! {
        mode == .tags ? tagsHeaderExpander : descriptionHeaderExpander
    }

    /// if the views were already built so we don't build 2 times
    var viewsBuilt: Bool = false

    /// - Parameters:
    ///   - localFiles:            access to local files
    ///   - photosToAdd:           array of images to show
    ///   - initialSelectedTags:   preselected tags
    ///   - initialDescription:    initial contents of the description text view
    init(localFiles: LocalFiles,
         photosViewModel: PhotosToAddViewModel,
         tagsViewModel: TagsViewModel,
         initialDescription: String)
    {
        self.localFiles = localFiles
        self.photosViewModel = photosViewModel
        self.tagsViewModel = tagsViewModel
        self.initialDescription = initialDescription
        super.init(nibName: nil, bundle: nil)

        tagsViewModel.addDelegate(self)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .dynamic(.Neutral_10)
        contentView.backgroundColor = .dynamic(.Neutral_10)
        navigationController?.isNavigationBarHidden = true
    }

    override dynamic var preferredStatusBarStyle: UIStatusBarStyle {
        UIStatusBarStyle.lightContent
    }

    /// build all the views when view will appear as we need to layout views for headers measurements
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !viewsBuilt {
            buildViews()
            view.setNeedsLayout()
            view.layoutIfNeeded()

            tagsHeaderExpander = HeaderExpander(
                drivingScrollView: tagsVC.tableView,
                contentView: contentView
            )
            tagsHeaderExpander.delegate = self
            descriptionHeaderExpander = HeaderExpander(
                drivingScrollView: descriptionView.textView,
                contentView: contentView
            )
            descriptionHeaderExpander.delegate = self
            // run the mode change related code initially
            newModeWillSet(.tags)
            newModeDidSet()
        }
        viewsBuilt = true

        // install keyboard observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        installHorizontalSwipeRecognizers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // photo alpha changes when header height changes
        updateHeaderPhotoAlpha()
    }
}

// MARK: - mode changes

extension PhotoDetailsViewController {
    /// adapts the UI to new mode that *will* be set
    private func newModeWillSet(_ mode: Mode) {
        // hide keyboard
        view.endEditing(true)

        // update views visibility
        tagsHeaderVC.view.isHidden = mode != .tags
        tagsVC.view.isHidden = mode != .tags
        descriptionView.isHidden = mode != .description

        // switch header expanders
        headerExpander.deactivate()
        if mode == .tags {
            tagsHeaderExpander.activate(headersInputMetrics: [headerInputMetrics(), tagsHeaderInputMetrics()])
        } else {
            descriptionHeaderExpander.activate(headersInputMetrics: [headerInputMetrics()])
            descriptionHeaderExpander.bottomContentEdgeInset = 16
        }
    }

    /// after new mode was set
    private func newModeDidSet() {
        if mode == .description {
            // this needs to happen after the mode was set so the keyboard handling works for
            // description

            // if nothing entered into description or description is in full view (headers collapsed)
            // then begin editing (this will also collapse the header)
            if !descriptionView.textView.hasText ||
                descriptionHeaderExpander.headersState.allCollapsed
            {
                descriptionView.textView.becomeFirstResponder()
            }
        }
    }

    private func installHorizontalSwipeRecognizers() {
        let leftSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(onHorizontalSwipe(_:)))
        leftSwipeRecognizer.direction = .left
        tagsVC.view.addGestureRecognizer(leftSwipeRecognizer)
        let rightSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(onHorizontalSwipe(_:)))
        rightSwipeRecognizer.direction = .right
        descriptionView.addGestureRecognizer(rightSwipeRecognizer)
    }

    @objc private func onHorizontalSwipe(_ sender: UISwipeGestureRecognizer) {
        if sender.direction == .left {
            mode = .description
            headerVC.tagsDescriptionSegmentedControl.setSelectedSegmentIndex(1, animated: true)
        }
        if sender.direction == .right {
            mode = .tags
            headerVC.tagsDescriptionSegmentedControl.setSelectedSegmentIndex(0, animated: true)
        }
    }
}

// MARK: - header scrolling

extension PhotoDetailsViewController: HeaderExpanderDelegate {
    /// Updates the alpha of the header photo based on the header height (to hide it when collapsing)
    /// This needs to be done here and not in the `PhotoDetailsHeaderView` as it is based on the max header photo height
    /// which is dependent on this view height
    private func updateHeaderPhotoAlpha() {
        guard headerExpander != nil else { return }
        // header photo alpha is 1 for the expanded header state and then drops to 0 when
        // header is 100pt high
        let maxHeight = headerInputMetrics().expandedHeight
        let currentHeight = headerExpander.headersState.heights[0]
        let alpha = currentHeight >= maxHeight
            ? 1.0
            : max((currentHeight - 100) / (maxHeight - 100), 0)
        headerVC.galleryVC.view.alpha = alpha
    }

    private func headerInputMetrics() -> HeaderInputMetrics {
        // initial height is the visible height of the header, which is not really a frame height
        // as the header get's negative top origin and keeps it's height, so the visible height
        // needs to account for that
        let initialHeight = headerVC.view.frame.origin.y + headerVC.view.frame.height
        let collapsedHeight = spaceBetweenViews / 2.0 /* = some space over the segmented control */ +
            SegmentedControl.height + spaceBetweenViews
        let expandedHeight = maxHeaderPhotoHeight() + spaceBetweenViews / 2.0 + collapsedHeight

        return HeaderInputMetrics(
            initialHeight: initialHeight,
            collapsedHeight: collapsedHeight,
            expandedHeight: expandedHeight
        )
    }

    private func maxHeaderPhotoHeight() -> CGFloat {
        // show the photo in correct aspect ratio, but no more than 0.6 height of the view for the header
        let imageHeight2WidthRatio = photosViewModel.photos.map(\.height2Width).max() ?? 4.0 / 3.0
        // 44 is the margins in the gallery view
        let imageHeight = (view.frame.width - 2 * 44.0) * imageHeight2WidthRatio
        return min(0.5 * view.frame.height, imageHeight)
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
        // the header height constant, we just update it's top to make it visually smaller and
        // drag the content up
        let expandedHeaderHeight = headerInputMetrics().expandedHeight
        let headerTop = min(0, heights[0] - expandedHeaderHeight)
        // start interactive photos expand if it's not in progress yet and user swiped down
        // (expanded the first header)
        if interactivePresentation == nil, heights[0] > expandedHeaderHeight {
            interactivePresentation = UIPercentDrivenInteractiveTransition()
            onPhotoSelected?(interactivePresentation)
        }
        // if interactive presentation is in progress, update it as the header expands
        if let interactivePresentation = interactivePresentation {
            if heights[0] < expandedHeaderHeight {
                // cancel the interactive presentation if minimized
                interactivePresentation.cancel()
                self.interactivePresentation = nil
            } else {
                let percent = (heights[0] - expandedHeaderHeight) / 100.0
                interactivePresentation.update(percent)
            }
        }
        headerViewTopConstraint?.update(offset: headerTop)
        headerViewHeightConstraint?.update(offset: expandedHeaderHeight)
        if heights.count > 1 {
            tagsHeaderViewHeightConstraint?.update(offset: heights[1])
        }
        if animationDuration > 0 {
            UIView.animate(withDuration: animationDuration) {
                self.view.layoutIfNeeded()
                self.updateHeaderPhotoAlpha()
            }
        } else {
            updateHeaderPhotoAlpha()
        }
        // if user expands the photo while editing the description let's end editing
        if mode == .description, case .expanded = expander.headersState.states[0] {
            view.endEditing(true)
        }
    }

    /// Finish the interactive presentation if it's currently in progress
    func headerExpanderWillEndExpanding(_ expander: HeaderExpander, withVelocity velocity: CGFloat) {
        if let interactivePresentation = interactivePresentation {
            let percent = (expander.headersState.heights[0] - headerInputMetrics().expandedHeight) / 100.0
            if velocity > 500 || percent > 0.5 {
                interactivePresentation.finish()
            } else {
                interactivePresentation.cancel()
            }
            self.interactivePresentation = nil
        }
    }
}

// MARK: - build views

extension PhotoDetailsViewController {
    /// entry function for building and laying out all the views
    private func buildViews() {
        buildHeaderView()
        buildTagsHeaderView()
        buildTagsView()
        buildDescriptionTextView()
        buildBottomBar()

        view.addSubview(contentView)
        add(childController: headerVC, toView: contentView)
        add(childController: tagsHeaderVC)
        contentView.insertSubview(tagsHeaderVC.view, belowSubview: headerVC.view)
        add(childController: tagsVC)
        contentView.insertSubview(tagsVC.view, belowSubview: tagsHeaderVC.view)
        contentView.insertSubview(descriptionView, belowSubview: headerVC.view)

        view.addSubview(bottomBar)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top).priority(.low)
        }
        headerVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            self.headerViewTopConstraint = make.top.equalToSuperview().constraint
            self.headerViewHeightConstraint = make.height.equalTo(headerInputMetrics().expandedHeight).constraint
        }
        tagsHeaderVC.view.snp.makeConstraints { make in
            make.top.equalTo(headerVC.view.snp.bottom)
            make.leading.trailing.equalToSuperview()
            self.tagsHeaderViewHeightConstraint = make.height.equalTo(tagsHeaderInputMetrics().expandedHeight)
                .constraint
        }
        tagsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(tagsHeaderVC.view.snp.bottom)
            make.bottom.equalTo(bottomBar.snp.top)
        }
        descriptionView.snp.makeConstraints { make in
            make.top.equalTo(headerVC.view.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            self.descriptionViewBottomConstraint = make.bottom.equalToSuperview().inset(16).constraint
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func buildHeaderView() {
        headerVC = PhotoDetailsHeaderViewController(localFiles: localFiles, photosViewModel: photosViewModel)
        headerVC.onPhotoSelected = { [weak self] in
            self?.onPhotoSelected?(nil)
        }
        headerVC.onAnnotationsSelected = { [weak self] in
            // in photo flow it doesn't matter whether user taps on photo or annotations button,
            // it will always open the fullscreen photo gallery that supports annotations
            self?.onPhotoSelected?(nil)
        }
        headerVC.onTagsSelected = { [weak self] in
            self?.mode = .tags
        }
        headerVC.onDescriptionSelected = { [weak self] in
            self?.mode = .description
        }
    }

    private func buildTagsHeaderView() {
        tagsHeaderVC = SearchAndSelectTagsHeaderViewController(
            viewModel: tagsViewModel,
            searchPlaceholderText: String(localized: "Search for, or add a tag")
        )
        tagsHeaderVC.searchView.textField.returnKeyType = .done
        tagsHeaderVC.searchView.addDelegate(self)
    }

    private func buildBottomBar() {
        bottomBar = UIView()
        bottomBar.backgroundColor = .dynamic(.Neutral_10)

        let stroke = UIView()
        stroke.backgroundColor = .dynamic(.Neutral_07)
        bottomBar.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        backButton = RangeButton(
            configuration: UIButton.Configuration.grayButton(),
            primaryAction: UIAction(title: backButtonLabel, image: backButtonImage) {
                [weak self] _ in self?.onBack?()
            }
        ).withCustomRangeHighlightColor()
        nextButton = RangeButton(
            configuration: UIButton.Configuration.blueButton(),
            primaryAction: UIAction(title: nextButtonLabel, image: nextButtonImage) {
                [weak self] _ in self?.onNext?()
            }
        ).withCustomRangeHighlightColor()
        bottomBar.addSubview(backButton)
        bottomBar.addSubview(nextButton)
        backButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nextButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
            make.trailing.equalTo(nextButton.snp.leading).offset(-16)
            make.width.equalTo(nextButton.snp.width)
            make.bottom.equalToSuperview().inset(AddPhotoConfirmationViewController.bottomPadding)
        }
        nextButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
        }
    }

    private func buildTagsView() {
        tagsVC = TagsSelectionViewController(viewModel: tagsViewModel)
        tagsVC.tableView.contentInsetAdjustmentBehavior = .never
        tagsVC.tableView.forwardDelegateInvocations(to: self)
        tagsVC.tableView.keyboardDismissMode = .onDrag
    }

    private func buildDescriptionTextView() {
        descriptionView = TextView(placeholderText:
            "Add a description...\nPro Tip: Any text added here will appear on PDF reports")
        descriptionView.textView.delegate = self
        descriptionView.onDone = { [weak self] in
            self?.view.endEditing(true)
            // expand the header
            self?.headerExpander.setFirstExpandedHeader(0, animated: true)
            self?.descriptionView.textView.setContentOffset(.zero, animated: true)
        }
        descriptionView.textView.text = initialDescription
//        descriptionView.textView.text =
//            """
//            1. This is the description that is being typed into the keyboard input
//            2. This is the description that is being typed into the keyboard input
//            3. This is the description that is being typed into the keyboard input
//            4. This is the description that is being typed into the keyboard input
//            5. dots:...................................................................................
//            6. This is the description that is being typed into the keyboard input
//            7. This is the description that is being typed into the keyboard input
//            8. This is the description that is being typed into the keyboard input
//            9. This is the description that is being typed into the keyboard input
//            10. This is the description that is being typed into the keyboard input
//            11. This is the description that is being typed into the keyboard input
//            """
    }
}

// MARK: tags handling

extension PhotoDetailsViewController: SearchViewDelegate, UIScrollViewDelegate {
    /// when the keyboard shows for the search tags collapse the main header, so the search field goes to the top
    func searchViewActivated(_: SearchView) {
        tagsHeaderExpander.setFirstExpandedHeader(1, animated: true)
    }

    /// on tags scroll adjust the header bottom stroke visibility
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === tagsVC.tableView {
            tagsHeaderVC.bottomStrokeVisible = scrollView.contentOffset.y > 0
        }
    }
}

// MARK: - tags view model delegate

extension PhotoDetailsViewController: TagsViewModelDelegate {
    /// React to selected tags changes by animating in/out the selected tags in the header and updating the header expander
    func tagsViewModel(_: TagsViewModel, tag _: TagViewModel, selected: Bool, indexInSelectedTags _: Int) {
        guard mode == .tags else { return }

        // only handle first selected tag (show tags) or last unselected (hide tags)
        guard (selected == true && tagsViewModel.selectedTags.count == 1)
            || (selected == false && tagsViewModel.selectedTags.count == 0) else { return }

        // deactive the expander as we'll be adjusting the header heights
        tagsHeaderExpander.deactivate()

        // calculate new tags header height keeping its collapsed/expanded state
        let newTagsHeaderHeight: CGFloat
        if case .collapsed = tagsHeaderExpander.headersState.states[1] {
            newTagsHeaderHeight = tagsHeaderInputMetrics(tagsVisible: selected).collapsedHeight
        } else {
            newTagsHeaderHeight = tagsHeaderInputMetrics(tagsVisible: selected).expandedHeight
        }

        let reactivateExpander = {
            // reactivate the expander with new metrics
            self.tagsHeaderExpander
                .activate(headersInputMetrics: [self.headerInputMetrics(), self.tagsHeaderInputMetrics()])
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

// MARK: description handling

extension PhotoDetailsViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_: UITextView) {
        // collapse header when starting editing
        headerExpander.setFirstExpandedHeader(1, animated: true)
    }

    func textViewDidChange(_: UITextView) {
        // back to collapsed when typing
        headerExpander.setFirstExpandedHeader(1, animated: true)
    }
}

// MARK: keyboard handling

extension PhotoDetailsViewController {
    /// Adjust the description constraints when keyboard shows
    @objc func keyboardWillShow(notification: NSNotification) {
        // Get required info out of the notification
        if let userInfo = notification.userInfo,
           let endValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey],
           let durationValue = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey],
           let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
        {
            // Transform the keyboard's frame into our view's coordinate system
            let endRect = view.convert((endValue as AnyObject).cgRectValue, from: view.window)

            if mode == .description {
                let scrollView = descriptionView.textView
                let scrollRect = scrollView.superview!.convert(scrollView.frame, to: view.window)
                // Find out how much the keyboard overlaps our scroll view
                let keyboardOverlap = scrollRect.maxY - endRect.origin.y + 16

                descriptionViewBottomConstraint?.update(inset: keyboardOverlap)
                descriptionHeaderExpander.bottomContentEdgeInset = keyboardOverlap
            }

            let duration = (durationValue as AnyObject).doubleValue
            let options = UIView.AnimationOptions(rawValue: UInt((curveValue as AnyObject).integerValue << 16))
            UIView.animate(withDuration: duration!, delay: 0, options: options, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }

    /// Reset description constraints when the keyboard hides
    @objc func keyboardWillHide(notification _: NSNotification) {
        if mode == .description {
            descriptionViewBottomConstraint?.update(inset: 16)
            descriptionHeaderExpander.bottomContentEdgeInset = 16
        }
    }
}
