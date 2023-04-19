import Foundation
import UIKit

/// Card view controller presenting a titled list of actions.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down, tap on the close button or choosing any action.
class ActionSelectorCardViewController: SheetCardViewController {
    private var actionsVC: ActionSelectorViewController!

    /// Initializer
    init(icon: UIImage?, title: String?, description: String? = nil, actions: [ActionItem]) {
        super.init(icon: icon, title: title, description: description)

        setupActions(actions: actions)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        add(childController: actionsVC, toView: containerView)
        actionsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            return baseHeight + actionsVC.tableView.contentSize.height + 16.0
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
