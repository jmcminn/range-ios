import Foundation
import UIKit

/// Extension for handling keyboard accessory view for text annotations
extension AnnotationsEditor {
    /// Setup a toolbar with "Recent texts" and "Done" buttons that will be shown above the keyboard
    func setupTextAnnotationInputAccessoryView() -> UIView {
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.isUserInteractionEnabled = true
        // width doesn't matter, will take as much as the keyboard
        blurEffectView.frame = CGRect(x: 0, y: 0, width: 100, height: 48)

        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
        buttonConfig.baseBackgroundColor = .clear
        buttonConfig.baseForegroundColor = .white
        buttonConfig.preferredSymbolConfigurationForImage = imageConfig
        buttonConfig.imagePlacement = .trailing
        buttonConfig.imagePadding = 5

        let recentTextButton = UIButton(
            configuration: buttonConfig,
            primaryAction: UIAction(title: "Recent Text",
                                    image: UIImage(systemName: "chevron.down.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.viewModel.recentTextSelectorVisible.toggle()
            }
        )
        blurEffectView.contentView.addSubview(recentTextButton)
        recentTextButton.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5)
        }

        buttonConfig.imagePlacement = .leading
        let doneButton = UIButton(
            configuration: buttonConfig,
            primaryAction: UIAction(title: "Done", image: UIImage(systemName: "checkmark")) { [weak self] _ in
                self?.viewModel.recentTextSelectorVisible = false
                self?.setEditing(nil)
            }
        )
        blurEffectView.contentView.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5)
        }

        // Recent texts button configuration update handler that changes the icon when the recent text selector is visible
        recentTextButton.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.imageColorTransformer = UIConfigurationColorTransformer { [weak self] incoming in
                guard let self = self else { return incoming }
                return self.viewModel.recentTextSelectorVisible ? .Primary_Blue_04 : .white
            }
            config?.image = self.viewModel.recentTextSelectorVisible
                ? UIImage(systemName: "chevron.down.circle.fill")
                : UIImage(systemName: "chevron.down.circle")
            button.configuration = config
        }

        // observe the recent text selector visibility and trigger the button update
        viewModel.$recentTextSelectorVisible
            .sink { _ in
                DispatchQueue.main.async {
                    recentTextButton.setNeedsUpdateConfiguration()
                }
            }
            .store(in: &subscriptions)

        return blurEffectView
    }
}
