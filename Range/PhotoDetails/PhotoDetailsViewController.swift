import Foundation
import UIKit

class PhotoDetailsViewController: UIViewController {
    var onBack: (() -> Void)?
    var onNext: (() -> Void)?

    var tagsDescriptionSegmentedControl: SegmentedControl?

    override func viewDidLoad() {
        // TODO: 51 dark only?
//        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        navigationController?.isNavigationBarHidden = true

        buildViews()
    }

    private func buildViews() {
        buildTagsDescriptionSegmentedControl()
        buildBottomBar()
    }

    private func updateColors() {
        tagsDescriptionSegmentedControl?.updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
}

// MARK: - build views

extension PhotoDetailsViewController {
    private func buildTagsDescriptionSegmentedControl() {
        let segmentedControl = SegmentedControl(items: [
            UIAction(title: "Tags", image: UIImage(systemName: "tag"), handler: { _ in print("tags") }),
            UIAction(
                title: "Description",
                image: UIImage(systemName: "text.quote"),
                handler: { _ in print("description") }
            ),
        ])
        view.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(50)
        }
        tagsDescriptionSegmentedControl = segmentedControl
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
