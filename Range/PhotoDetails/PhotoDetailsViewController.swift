import Foundation
import UIKit

// TODO: 51 headers:
// Dragging:
/// header 1
/// header 2
/// scroll View
///
/// header n can drag up/down headers [1...n]
///
/// scroll view drags everything
/// header can be configured to expand:
/// a) on offset 0 (once the scroll scrolled to the top)
///   XOR
/// b) expand early (on drag down)
/// scroll view collapses headers 1 -> n
/// expands n -> 1

class PhotoDetailsViewController: UIViewController {
    unowned let model: ProjectModel
    /// The photo
    let image: UIImage

    var onBack: (() -> Void)?
    var onNext: (() -> Void)?

    var bottomBar: UIView!
    var photoView: UIImageView!
    var tagsDescriptionSegmentedControl: SegmentedControl!
    var tagsSearchView: SearchView!
//    var tagsVC: TagsViewController!

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

        buildViews()
        updateColors()
    }

    private func buildViews() {
        buildBottomBar()

        buildPhotoView()
        buildTagsDescriptionSegmentedControl()
        buildTagsSearchView()
        buildTagsView()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// update colors that don't adapt automatically to appearance change
    private func updateColors() {
        photoView?.layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
        tagsDescriptionSegmentedControl?.updateColors()
        tagsSearchView?.updateColors()
    }
}

// MARK: - build views

extension PhotoDetailsViewController {
    private func buildPhotoView() {
        photoView = UIImageView(image: image)
        let height2WidthRatio = image.size.height / image.size.width
        photoView.layer.cornerRadius = 13
        photoView.layer.borderWidth = 1
        photoView.clipsToBounds = true
        photoView.contentMode = .scaleAspectFill
        view.addSubview(photoView)
        photoView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            // try to keep the aspect ratio (but priority is high and not required)
            make.height.equalTo(photoView.snp.width).multipliedBy(height2WidthRatio).priority(.high)
            // not take more than 0.6 of the view
            // TODO: 51 bring back the 0.6 version
            make.height.lessThanOrEqualToSuperview().multipliedBy(0.2)
        }
    }

    private func buildTagsDescriptionSegmentedControl() {
        tagsDescriptionSegmentedControl = SegmentedControl(items: [
            UIAction(
                title: String(localized: "Tags"),
                image: UIImage(systemName: "tag"),
                handler: { _ in print("tags") }
            ),
            UIAction(
                title: String(localized: "Description"),
                image: UIImage(systemName: "text.quote"),
                handler: { _ in print("description") }
            ),
        ])
        view.addSubview(tagsDescriptionSegmentedControl)
        tagsDescriptionSegmentedControl.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(photoView.snp.bottom).offset(16)
        }
    }

    private func buildTagsSearchView() {
        tagsSearchView = SearchView(placeholderText: String(localized: "Search for, or add a tag"))
        view.addSubview(tagsSearchView)
        tagsSearchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
            make.top.equalTo(tagsDescriptionSegmentedControl.snp.bottom).offset(16)
        }
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
        }
        nextButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
        }

        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(backButton.snp.height)
                .offset(AddPhotoConfirmationViewController.topPadding + AddPhotoConfirmationViewController
                    .bottomPadding)
        }
    }

    private func buildTagsView() {
        let tagsVC = TagsViewController(model: model)
        add(childController: tagsVC)
        tagsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(tagsSearchView.snp.bottom).offset(16)
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }
}
