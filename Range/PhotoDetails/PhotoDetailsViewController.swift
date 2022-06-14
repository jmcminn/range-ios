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
    unowned let model: ProjectModel
    /// The photo
    let image: UIImage

    /// The mode of the PhotoDetailsViewController
    private enum Mode {
        case tags // showing tags
        case description // showing description
    }

    private var mode: Mode = .tags {
        willSet(newMode) {
            guard newMode != mode else { return }
            updateUIForMode(newMode)
        }
    }

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
    var headerView: PhotoDetailsHeaderView!
    var headerViewHeightConstraint: Constraint?
    var tagsHeaderView: PhotoDetailsTagsHeaderView!
    var tagsHeaderViewHeightConstraint: Constraint?

    var bottomBar: UIView!

    /// the content and constraints
    var tagsVC: TagsViewController!
    var descriptionView: TextView!
    var descriptionViewBottomConstraint: Constraint?

    /// tags expander - activated when mode == .tags
    var tagsHeaderExpander: HeaderExpander!
    /// description expander - activated when mode == .description
    var descriptionHeaderExpander: HeaderExpander!
    /// a convenience getter for the current expander based on the mode
    var headerExpander: HeaderExpander {
        mode == .tags ? tagsHeaderExpander : descriptionHeaderExpander
    }

    /// - Parameters:
    ///   - model:          model
    ///   - image:          photo to tag, ...
    init(model: ProjectModel, image: UIImage) {
        self.model = model
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        // TODO: 51 dark only?
//        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        contentView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        navigationController?.isNavigationBarHidden = true
    }

    /// build all the views when view will appear as we need to layout views for headers measurements
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buildViews()
        updateColors()
        view.setNeedsLayout()
        view.layoutIfNeeded()

        tagsHeaderExpander = HeaderExpander(
            drivingScrollView: tagsVC.tableView,
            contentView: contentView,
            headersHeightsUpdateCallback: { [weak self] in
                self?.updateHeaders(heights: $0, animationDuration: $1)
            }
        )
        descriptionHeaderExpander = HeaderExpander(
            drivingScrollView: descriptionView.textView,
            contentView: contentView,
            headersHeightsUpdateCallback: { [weak self] in
                self?.updateHeaders(heights: $0, animationDuration: $1)
            }
        )
        updateUIForMode(.tags)

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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
    }

    // TODO: 51 move it to a separate PhotoDetailsDescriptionHandler
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

            // TODO: 51 refactor this method to make it shorter
            if mode == .description {
                let scrollView = descriptionView.textView
                let scrollRect = scrollView.convert(scrollView.frame, to: view.window)
                // Find out how much the keyboard overlaps our scroll view
                let keyboardOverlap = scrollRect.maxY - endRect.origin.y

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
            descriptionViewBottomConstraint?.update(inset: 0)
            descriptionHeaderExpander.bottomContentEdgeInset = 0
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // photo alpha changes when header height changes
        updateHeaderPhotoAlpha()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// update colors that don't adapt automatically to appearance change
    private func updateColors() {
        headerView?.updateColors()
        tagsHeaderView?.updateColors()
        descriptionView?.updateColors()
    }
}

// MARK: - mode changes

extension PhotoDetailsViewController {
    /// adapts the UI to new mode
    private func updateUIForMode(_ mode: Mode) {
        // hide keyboard
        view.endEditing(true)

        // update views visibility
        tagsHeaderView.isHidden = mode != .tags
        tagsVC.view.isHidden = mode != .tags
        descriptionView.isHidden = mode != .description

        // switch header expanders
        headerExpander.deactivate()
        if mode == .tags {
            tagsHeaderExpander.activate(headersInputMetrics: [headerInputMetrics(), tagsHeaderInputMetrics()])
        } else {
            descriptionHeaderExpander.activate(headersInputMetrics: [headerInputMetrics()])
            descriptionHeaderExpander.bottomContentEdgeInset = 0

            // if nothing entered into description then begin editing (this will also collapse
            // the header)
            if !descriptionView.textView.hasText {
                descriptionView.textView.becomeFirstResponder()
            }
        }
    }
}

// MARK: - header scrolling

extension PhotoDetailsViewController {
    /// Updates the alpha of the header photo based on its height (to hide it when collapsing)
    /// This needs to be done here and not in the `PhotoDetailsHeaderView` as it is based on the max header photo height
    /// which is dependent on this view height
    private func updateHeaderPhotoAlpha() {
        // header photo alpha is 1 for the expanded header state and then drops to 0 when
        // photo is 50pt high
        let maxPhotoViewHeight = maxHeaderPhotoHeight()
        let alpha = headerView.photoView.frame.height >= maxPhotoViewHeight
            ? 1.0
            : max((headerView.photoView.frame.height - 50) / (maxPhotoViewHeight - 50), 0)
        headerView.photoView.alpha = alpha
    }

    private func headerInputMetrics() -> HeaderInputMetrics {
        let collapsedHeight = spaceBetweenViews / 2.0 /* = some space over the segmented control */ +
            SegmentedControl.height + spaceBetweenViews
        let expandedHeight = maxHeaderPhotoHeight() + spaceBetweenViews / 2.0 + collapsedHeight

        return HeaderInputMetrics(
            initialHeight: headerView.frame.height,
            collapsedHeight: collapsedHeight,
            expandedHeight: expandedHeight
        )
    }

    private func maxHeaderPhotoHeight() -> CGFloat {
        // show the photo in correct aspect ratio, but no more than 0.6 height of the view for the header
        let imageHeight2WidthRatio = image.size.height / image.size.width
        // 16 is the margins
        let imageHeight = (view.frame.width - 2 * 16.0) * imageHeight2WidthRatio
        return min(0.5 * view.frame.height, imageHeight)
    }

    private func tagsHeaderInputMetrics() -> HeaderInputMetrics {
        HeaderInputMetrics(initialHeight: tagsHeaderView.frame.height,
                           collapsedHeight: 32 /* =selected tags height */ + 16 /* = spaceBetweenViews*/,
                           expandedHeight: 40 /* =search */ + 16 /* = padding*/ + 32 /* = selected tags height */ + 16)
    }

    func updateHeaders(heights: [CGFloat], animationDuration: TimeInterval) {
        headerViewHeightConstraint?.update(offset: heights[0])
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
        contentView.addSubview(headerView)
        contentView.insertSubview(tagsHeaderView, belowSubview: headerView)
        add(childController: tagsVC)
        contentView.insertSubview(tagsVC.view, belowSubview: tagsHeaderView)
        contentView.insertSubview(descriptionView, belowSubview: headerView)

        view.addSubview(bottomBar)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top).priority(.low)
        }
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            self.headerViewHeightConstraint = make.height.equalTo(headerInputMetrics().expandedHeight).constraint
        }
        tagsHeaderView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            self.tagsHeaderViewHeightConstraint = make.height.equalTo(tagsHeaderInputMetrics().expandedHeight)
                .constraint
        }
        tagsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(tagsHeaderView.snp.bottom)
            make.bottom.equalTo(bottomBar.snp.top)
        }
        descriptionView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            self.descriptionViewBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func buildHeaderView() {
        headerView = PhotoDetailsHeaderView(image: image)
        headerView.onTagsSelected = { [weak self] in
            self?.mode = .tags
        }
        headerView.onDescriptionSelected = { [weak self] in
            self?.mode = .description
        }
    }

    private func buildTagsHeaderView() {
        tagsHeaderView = PhotoDetailsTagsHeaderView()
        tagsHeaderView.searchView.delegate = self
    }

    private func buildBottomBar() {
        bottomBar = UIView()
        bottomBar.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        let stroke = UIView()
        stroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_08)
        bottomBar.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        let backButton = UIButton(
            configuration: UIButton.Configuration.bottomBackButton(),
            primaryAction: UIAction(
                title: String(localized: "Back"),
                image: UIImage(systemName: "arrow.backward")
            ) { [weak self] _ in self?.onBack?() }
        )
        let nextButton = UIButton(
            configuration: UIButton.Configuration.bottomNextButton(),
            primaryAction: UIAction(
                title: String(localized: "Next"),
                image: UIImage(systemName: "arrow.forward")
            ) { [weak self] _ in self?.onNext?() }
        )
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
        tagsVC = TagsViewController(model: model)
        tagsVC.tableView.contentInsetAdjustmentBehavior = .never
        tagsVC.tableView.forwardDelegateInvocations(to: self)
    }

    private func buildDescriptionTextView() {
        descriptionView = TextView(placeholderText: "Add a description")
        descriptionView.textView.delegate = self
        descriptionView.onDone = { [weak self] in
            self?.view.endEditing(true)
            // expand the header
            self?.headerExpander.setFirstExpandedHeader(0, animated: true)
            self?.descriptionView.textView.setContentOffset(.zero, animated: true)
        }
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

// TODO: 51 move it to PhotoDetailsTagsHandler
extension PhotoDetailsViewController: SearchViewDelegate, UIScrollViewDelegate {
    /// when the keyboard shows for the search tags collapse the main header, so the search field goes to the top
    func searchViewActivated(_: SearchView) {
        tagsHeaderExpander.setFirstExpandedHeader(1, animated: true)
    }

    /// on tags scroll end the editing and adjust the header bottom stroke visibility
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === tagsVC.tableView {
            view.endEditing(true)
            tagsHeaderView.bottomStrokeVisible = scrollView.contentOffset.y > 0
        }
    }
}

// MARK: description handling

// TODO: 51 move it to PhotoDetailsDescriptionHandler
extension PhotoDetailsViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_: UITextView) {
        // collapse header when starting editing
        headerExpander.setFirstExpandedHeader(1, animated: true)
        descriptionView.contentHugging = false
    }

    func textViewDidChange(_: UITextView) {
        // back to collapsed when typing
        headerExpander.setFirstExpandedHeader(1, animated: true)
    }

    func textViewDidEndEditing(_: UITextView) {
        descriptionView.contentHugging = true
    }
}
