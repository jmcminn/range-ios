import SnapKit
import UIKit

class ProjectActionCardViewController: UIViewController, CardCoordinating {
    var cardDisplayController: CardDisplayController?
    
    
    static let topPadding = 21.0
    static let headerToActionsPadding = 16.0
    
    var searchBackground = UIView()
    var searchIcon: UIImageView!
    var searchTextField: UITextField!
    var photoButton: UIButton!
    var actionSelectorVC: ProjectActionSelectorViewController!
    
    var containerView: UIView {
        return (view as! RoundShadowView).containerView
    }
    
    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = Colors.Neutral_10
        updateShadow()
        
        containerView.addSubview(searchBackground)
        searchBackground.backgroundColor = Colors.Neutral_09
        searchBackground.layer.cornerRadius = 12
        searchBackground.layer.borderWidth = 1
        searchBackground.layer.borderColor = Colors.Neutral_08.cgColor
        
        let searchImage = UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .subheadline).applying(UIImage.SymbolConfiguration(weight: .medium))
        )
        searchIcon = UIImageView(image: searchImage)
        searchIcon.tintColor = Colors.Neutral_05
        searchIcon.setContentHuggingPriority(.required, for: .horizontal)
        searchIcon.setContentHuggingPriority(.required, for: .vertical)
        
        searchTextField = UITextField()
        searchTextField.placeholder = "Search"
        searchTextField.font = UIFont.preferredFont(forTextStyle: .body)
        searchTextField.adjustsFontForContentSizeCategory = true
        searchTextField.isUserInteractionEnabled = false
        
        searchBackground.addSubview(searchIcon)
        searchBackground.addSubview(searchTextField)
        
        let photoImage = UIImage(
            systemName: "camera",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .subheadline).applying(UIImage.SymbolConfiguration(weight: .medium))
        )
        
        var photoButtonConfig = UIButton.Configuration.filled()
        photoButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 12.5, bottom: 15, trailing: 12.5)
        photoButtonConfig.background.cornerRadius = 12
        photoButtonConfig.background.strokeColor = Colors.Primary_Blue_06
        photoButtonConfig.baseForegroundColor = Colors.Misc_White
        photoButtonConfig.baseBackgroundColor = Colors.Primary_Blue_04
        
        photoButton = UIButton(configuration: photoButtonConfig, primaryAction: UIAction(image: photoImage) { _ in })
        photoButton.setContentHuggingPriority(.required, for: .horizontal)
        photoButton.setContentHuggingPriority(.required, for: .vertical)
        containerView.addSubview(photoButton)
        
        photoButton.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.top.equalTo(ProjectActionCardViewController.topPadding)
        }
        searchBackground.snp.makeConstraints { make in
            make.top.equalTo(photoButton)
            make.left.equalTo(16)
            make.height.equalTo(photoButton)
            make.right.equalTo(photoButton.snp.left).offset(-16)
        }
        searchIcon.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
        }
        searchTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(searchIcon.snp.right).offset(12)
            make.right.equalToSuperview()
        }
        
        actionSelectorVC = ProjectActionSelectorViewController()
        add(childController: actionSelectorVC, toView: containerView)
        actionSelectorVC.view.snp.makeConstraints { make in
            make.top.equalTo(photoButton.snp.bottom).offset(ProjectActionCardViewController.headerToActionsPadding).priority(.required)
            make.width.equalToSuperview()
            make.bottom.equalToSuperview().priority(.required)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if (traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection)) {
            searchBackground.layer.borderColor = Colors.Neutral_08.cgColor
            updateShadow()
        }
    }
    
    private func updateShadow() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        view.layer.shadowOpacity = darkMode ? 0.2 : 0.05
        view.layer.shadowColor = Colors.Shadow.cgColor
    }
}

extension ProjectActionCardViewController: CardPresentable {
    func height(forWidth width: CGFloat, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }
        
        let fittingSize = CGSize(
            width: width,
            height: UIView.layoutFittingCompressedSize.height
        )
        
        var height = (
            ProjectActionCardViewController.topPadding +
            photoButton.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultLow).height +
            ProjectActionCardViewController.headerToActionsPadding
        )
        
        if cardPosition == .max {
            height += actionSelectorVC.tableView.contentSize.height
        }
        
        return height
    }
    
    func drivingScrollView() -> UIScrollView? {
        return actionSelectorVC.tableView
    }
}
