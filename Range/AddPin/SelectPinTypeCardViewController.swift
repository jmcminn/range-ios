import Foundation
import UIKit

/// Card view controller presenting a choice of Photo Pin and Task Pin
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down, tap on the close button or choosing any action.
class SelectPinTypeCardViewController: SheetCardViewController {
    private let photoPinButton = SelectPinTypeButton(type: .createPhoto)
    private let taskPinButton = SelectPinTypeButton(type: .createTask)
    private let copyTaskPinButton = SelectPinTypeButton(type: .copyTask)

    /// Callback for pin selected, optional = nil when the selector was dismissed
    var onPinTypeSelected: ((PinTypeOption?) -> Void)?

    /// Initializer
    init(onPinTypeSelected: ((PinTypeOption?) -> Void)? = nil) {
        self.onPinTypeSelected = onPinTypeSelected
        super.init(icon: UIImage(systemName: "mappin.and.ellipse"), title: String(localized: "Add Pin"))
        onCancel = { [weak self] in self?.onPinTypeSelected?(nil) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        photoPinButton.addTarget(self, action: #selector(photoPinSelected), for: .touchUpInside)
        taskPinButton.addTarget(self, action: #selector(taskPinSelected), for: .touchUpInside)

        containerView.addSubview(photoPinButton)
        containerView.addSubview(taskPinButton)

        photoPinButton.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        taskPinButton.snp.makeConstraints { make in
            make.top.equalTo(photoPinButton.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        copyTaskPinButton.addTarget(self, action: #selector(copyTaskPinSelected), for: .touchUpInside)
        containerView.addSubview(copyTaskPinButton)
        copyTaskPinButton.snp.makeConstraints { make in
            make.top.equalTo(taskPinButton.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        var baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            baseHeight += photoPinButton.frame.height + 16.0 + taskPinButton.frame.height
                + 16.0 + copyTaskPinButton.frame.height
        }
        return baseHeight
    }

    @objc private func photoPinSelected() {
        dismissCard()
        onPinTypeSelected?(.createPhoto)
    }

    @objc private func taskPinSelected() {
        dismissCard()
        onPinTypeSelected?(.createTask)
    }

    @objc private func copyTaskPinSelected() {
        dismissCard()
        onPinTypeSelected?(.copyTask)
    }
}
