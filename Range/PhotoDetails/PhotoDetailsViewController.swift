import Foundation
import SnapKit
import UIKit

class PhotoDetailsViewController: UIViewController {
    unowned let model: ProjectModel
    /// The photo
    let image: UIImage

    var onBack: (() -> Void)?
    var onNext: (() -> Void)?

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
//        view.setNeedsLayout()
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

    private func headerInputMetrics() -> HeaderInputMetrics {
        let spaceBetweenViews = 16.0
        let horizontalMargin = 16.0
        let collapsedHeight = SegmentedControl.height + spaceBetweenViews

        // show the photo in correct aspect ratio, but no more than 0.6 height of the view for the header
        let imageHeight2WidthRatio = image.size.height / image.size.width
        // 16 is the margins
        let imageHeight = (view.frame.width - 2 * horizontalMargin) * imageHeight2WidthRatio
        // TODO: 51 0.6
        let expandedHeight = min(0.5 * view.frame.height, imageHeight + spaceBetweenViews + collapsedHeight)

        return HeaderInputMetrics(
            initialHeight: headerView.frame.height,
            collapsedHeight: collapsedHeight,
            expandedHeight: expandedHeight
        )
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
            // TODO: 51 headerexpander2:
//            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            // TODO: 51 headerexpander3:
            make.top.equalTo(tagsHeaderView.snp.bottom)
            make.bottom.equalTo(bottomBar.snp.top)
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
//            make.height.equalTo(backButton.snp.height)
//                .offset(AddPhotoConfirmationViewController.topPadding + AddPhotoConfirmationViewController
//                    .bottomPadding)
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
        // TODO: 51
        headerViewHeightConstraint?.update(offset: heights[0])
        tagsHeaderViewHeightConstraint?.update(offset: heights[1])
        if animationDuration > 0 {
            UIView.animate(withDuration: animationDuration) {
                self.view.layoutIfNeeded()
            }
        }
    }
}

// MARK: - build views

extension PhotoDetailsViewController {
    private func buildHeaderView() {
        headerView = PhotoDetailsHeaderView(image: image)
        // TODO: 51
//        headerView.layer.borderWidth = 0.5
//        headerView.layer.borderColor = UIColor.orange.withAlphaComponent(0.2).cgColor
    }

    private func buildTagsHeaderView() {
        tagsHeaderView = PhotoDetailsTagsHeaderView()
        // TODO: 51
//        tagsHeaderView.layer.borderWidth = 0.5
//        tagsHeaderView.layer.borderColor = UIColor.yellow.withAlphaComponent(0.2).cgColor
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
        // TODO: 51 never?
        tagsVC.tableView.contentInsetAdjustmentBehavior = .never
        tagsVC.onScroll = { [weak self] in
            self?.view.endEditing(true)
        }
    }
}
