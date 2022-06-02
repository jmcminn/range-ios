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

// MARK: - Bottom Back/Next navigation

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

        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .regular))

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 28,
            bottom: 15,
            trailing: 28
        )
        buttonConfig.background.cornerRadius = 12
        buttonConfig.imagePadding = 5
        buttonConfig.preferredSymbolConfigurationForImage = imageConfig

        var backConfig = buttonConfig
        backConfig.baseBackgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        backConfig.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        backConfig.background.strokeColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_08)
        backConfig.imagePlacement = .leading

        var nextConfig = buttonConfig
        nextConfig.baseBackgroundColor = .Primary_Blue_04
        nextConfig.baseForegroundColor = .Neutral_01
        nextConfig.imagePlacement = .trailing

        let backButton = UIButton(
            configuration: backConfig,
            primaryAction: UIAction(
                title: "Back",
                image: UIImage(systemName: "arrow.backward")
            ) { [weak self] _ in self?.onBack?() }
        )
        let nextButton = UIButton(
            configuration: nextConfig,
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
