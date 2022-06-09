import Foundation
import SnapKit
import UIKit

class PhotoDetailsViewController: UIViewController {
    unowned let model: ProjectModel
    /// The photo
    let image: UIImage

    var onBack: (() -> Void)?
    var onNext: (() -> Void)?

    /// vertical space between the views
    private let spaceBetweenViews = 16.0
    /// margin on the left/right
    private let horizontalMargin = 16.0
    var headerView: PhotoDetailsHeaderView!
    var headerViewHeightConstraint: Constraint?
    var tagsHeaderView: PhotoDetailsTagsHeaderView!
    var tagsHeaderViewHeightConstraint: Constraint?

    var bottomBar: UIView!

    var tagsVC: TagsViewController!

    var tagsHeaderExpander: HeaderExpander!

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
        navigationController?.isNavigationBarHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buildViews()
        updateColors()
        view.layoutIfNeeded()

        tagsHeaderExpander = HeaderExpander(
            drivingScrollView: tagsVC.tableView,
            viewToPan: view,
            configuration: [.expandLate, .expandEarly],
            headersHeightsUpdateCallback: { [weak self] in
                self?.updateHeaders(heights: $0, animationDuration: $1)
            }
        )
        tagsHeaderExpander.activate(headersInputMetrics: [headerInputMetrics(), tagsHeaderInputMetrics()])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateHeaderPhotoAlpha()
    }

    /// Updates the alpha of the header photo based on its height (to hide it when collapsing)
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

    private func buildViews() {
        buildHeaderView()
        buildTagsHeaderView()
        buildTagsView()
        buildBottomBar()

        view.addSubview(headerView)
        view.insertSubview(tagsHeaderView, belowSubview: headerView)
        add(childController: tagsVC)
        view.insertSubview(tagsVC.view, belowSubview: tagsHeaderView)
        view.addSubview(bottomBar)

        headerView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
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
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
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
    }
}

// MARK: - header scrolling

extension PhotoDetailsViewController {
    func updateHeaders(heights: [CGFloat], animationDuration: TimeInterval) {
        headerViewHeightConstraint?.update(offset: heights[0])
        tagsHeaderViewHeightConstraint?.update(offset: heights[1])
        if animationDuration > 0 {
            UIView.animate(withDuration: animationDuration) {
                self.view.layoutIfNeeded()
                self.updateHeaderPhotoAlpha()
            }
        }
    }
}

// MARK: - build views

extension PhotoDetailsViewController {
    private func buildHeaderView() {
        headerView = PhotoDetailsHeaderView(image: image)
    }

    private func buildTagsHeaderView() {
        tagsHeaderView = PhotoDetailsTagsHeaderView()
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
        tagsVC.onScroll = { [weak self] in
            self?.view.endEditing(true)
        }
    }
}
