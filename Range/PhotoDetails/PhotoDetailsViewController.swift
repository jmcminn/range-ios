import Foundation
import UIKit

class PhotoDetailsViewController: UIViewController {
    /// The photo
    let image: UIImage

    var onBack: (() -> Void)?
    var onNext: (() -> Void)?

    var photoView: UIImageView!
    var tagsDescriptionSegmentedControl: SegmentedControl!
    var tagsSearchView: SearchView!

    /// - Parameters:
    ///   - image:          photo to tag, ...
    init(image: UIImage) {
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
        buildPhotoView()
        buildTagsDescriptionSegmentedControl()
        buildTagsSearchView()
        buildBottomBar()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// update colors that don't adapt automatically to appearance change
    private func updateColors() {
        photoView.layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
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
            make.height.lessThanOrEqualToSuperview().multipliedBy(0.6)
        }
    }

    private func buildTagsDescriptionSegmentedControl() {
        tagsDescriptionSegmentedControl = SegmentedControl(items: [
            UIAction(title: "Tags", image: UIImage(systemName: "tag"), handler: { _ in print("tags") }),
            UIAction(
                title: "Description",
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
        tagsSearchView = SearchView(placeholderText: "Search for, or add a tag")
        view.addSubview(tagsSearchView)
        tagsSearchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
            make.top.equalTo(tagsDescriptionSegmentedControl.snp.bottom).offset(16)
        }
    }

    private func buildBottomBar() {
        let bottomBarView = UIView()
        bottomBarView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        let stroke = UIView()
        stroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_08)
        bottomBarView.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        let backButton = UIButton(
            configuration: UIButton.Configuration.bottomBackButton(),
            primaryAction: UIAction(
                title: "Back",
                image: UIImage(systemName: "arrow.backward")
            ) { [weak self] _ in self?.onBack?() }
        )
        let nextButton = UIButton(
            configuration: UIButton.Configuration.bottomNextButton(),
            primaryAction: UIAction(
                title: "Next",
                image: UIImage(systemName: "arrow.forward")
            ) { [weak self] _ in self?.onNext?() }
        )
        bottomBarView.addSubview(backButton)
        bottomBarView.addSubview(nextButton)
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

        view.addSubview(bottomBarView)
        bottomBarView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(backButton.snp.height)
                .offset(AddPhotoConfirmationViewController.topPadding + AddPhotoConfirmationViewController
                    .bottomPadding)
        }
    }
}
