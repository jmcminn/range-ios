import Foundation
import UIKit

/// Card view controller presenting a titled list of actions.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down, tap on the close button or choosing any action.
class ActionSelectorCardViewController: SheetCardViewController {
    private var actionsVC: ActionSelectorViewController!

    /// Initializer
    init(icon: UIImage?, title: String?, subtitle: String? = nil, actions: [ActionItem]) {
        super.init(icon: icon, title: title, subtitle: subtitle)

        setupActions(actions: actions)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        add(childController: actionsVC, toView: containerView)
        actionsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            if let subtitleLabel = subtitleLabel {
                make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            } else {
                make.top.equalTo(closeButton.snp.bottom).offset(16)
            }
            make.bottom.equalToSuperview().inset(12)
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            return baseHeight + actionsVC.tableView.contentSize.height + 12.0
        }
        return baseHeight
    }

    override func drivingScrollView() -> UIScrollView? {
        actionsVC.tableView
    }
}

// MARK: Views

extension ActionSelectorCardViewController {
    /// Setup ActionSelectorViewController for given actions. Enhance the action handlers to dismiss this card
    private func setupActions(actions: [ActionItem]) {
        let actions = actions.map { action in
            ActionItem(
                title: action.title,
                imageName: action.imageName,
                style: action.style,
                handler: { [weak self] in
                    action.handler?()
                    self?.dismissCard()
                }
            )
        }
        actionsVC = ActionSelectorViewController(actions: actions)
    }
}
