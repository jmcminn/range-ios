import Foundation
import UIKit

/// Card view controller presenting a choice of Photo Pin and Task Pin
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down, tap on the close button or choosing any action.
class SelectPinTypeCardViewController: SheetCardViewController {
    private let photoPinButton = SelectPinTypeButton(type: .photo)
    private let taskPinButton = SelectPinTypeButton(type: .task)

    /// Callback for pin selected, optional = nil when the selector was dismissed
    var onPinTypeSelected: ((PinType?) -> Void)?

    /// Initializer
    init(onPinTypeSelected: ((PinType?) -> Void)? = nil) {
        self.onPinTypeSelected = onPinTypeSelected
        super.init(icon: UIImage(systemName: "mappin.and.ellipse"), title: String(localized: "Add Pin"))
        onDismiss = { [weak self] in self?.onPinTypeSelected?(nil) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        photoPinButton.addTarget(self, action: #selector(photoPinSelected), for: .touchUpInside)
        taskPinButton.addTarget(self, action: #selector(taskPinSelected), for: .touchUpInside)

        containerView.addSubview(photoPinButton)
        containerView.addSubview(taskPinButton)

        photoPinButton.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.equalTo(16)
            make.width.equalToSuperview().multipliedBy(0.5).offset(-24)
        }

        taskPinButton.snp.makeConstraints { make in
            make.top.height.width.equalTo(photoPinButton)
            make.trailing.equalTo(-16)
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + photoPinButton.frame.height + 16.0
        }
        return baseHeight
    }

    @objc private func photoPinSelected() {
        dismissCard()
        onPinTypeSelected?(.photo)
    }

    @objc private func taskPinSelected() {
        dismissCard()
        onPinTypeSelected?(.task)
    }
}
