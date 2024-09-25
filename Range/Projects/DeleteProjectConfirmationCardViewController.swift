import Foundation
import UIKit

class DeleteProjectConfirmationCardViewController: SheetCardViewController, UITextFieldDelegate {
    private let projectName: String
    private let confirmLabel = UILabel()
    private let textFieldBackground = UIView()
    private let textField = UITextField()
    private var actionsVC: ActionSelectorViewController!

    /// how high is the currently visible part of the keyboard
    private var keyboardHeightInWindow: CGFloat = 0

    var onDelete: (() -> Void)?

    init(_ project: ProjectSummary) {
        projectName = project.name
        super.init(icon: nil,
                   title: "Are you sure you want to delete this project?",
                   description: "Deleting this project means that all data will be lost forever. It CAN’T be recovered. Alternative you can “Archive” the project.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupConfirmLabel()
        containerView.addSubview(confirmLabel)
        confirmLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sheetHeaderView.snp.bottom)
        }

        setupTextField()
        containerView.addSubview(textFieldBackground)
        textFieldBackground.snp.makeConstraints { make in
            make.top.equalTo(confirmLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        actionsVC = ActionSelectorViewController(actions: [
            ActionItem(
                title: "Delete Project",
                imageName: "trash", style: .destructive, handler: { [weak self] in
                    self?.dismissCard()
                    self?.onDelete?()
                }
            ),
            ActionItem(title: "Cancel", imageName: "xmark", handler: { [weak self] in
                self?.dismissCard()
            }),
        ])
        add(childController: actionsVC, toView: containerView)
        actionsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(textFieldBackground.snp.bottom).offset(16)
            make.bottom.equalToSuperview().inset(16)
        }
        actionsVC.setActionEnabled(false, atIndex: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // install keyboard observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // remove keyboard observers
        NotificationCenter.default.removeObserver(self)
    }

    private func setupConfirmLabel() {
        let attributedText = NSMutableAttributedString(
            string: "Confirm you’d like to delete the project by typing the \(projectName) below.",
            attributes: [
                .foregroundColor: UIColor.dynamic(.Neutral_05),
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
            ]
        )
        if let range = attributedText.string.range(of: projectName) {
            let nsRange = NSRange(range, in: attributedText.string)
            attributedText.setAttributes([
                .foregroundColor: UIColor.Red_03,
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
            ], range: nsRange)
        }
        confirmLabel.attributedText = attributedText
        confirmLabel.numberOfLines = 0
        confirmLabel.lineBreakMode = .byWordWrapping
        confirmLabel.adjustsFontForContentSizeCategory = true
    }

    /// Setup the text field used for entering the search term
    private func setupTextField() {
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.tintColor = .Red_03
        textField.textColor = .Red_03
        textField.autocapitalizationType = .none
        // don't show the default clear button
        textField.clearButtonMode = .never
        textField.attributedPlaceholder = NSAttributedString(
            string: projectName,
            attributes: [.foregroundColor: UIColor.Red_02]
        )
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChangedAction), for: .editingChanged)
        textField.returnKeyType = .done

        textFieldBackground.layer.cornerRadius = 12
        textFieldBackground.layer.borderWidth = 1
        textFieldBackground.backgroundColor = .dynamic(.Neutral_09)

        textFieldBackground.addSubview(textField)
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }

    @objc func textChangedAction() {
        let deleteEnabled = textField.text == projectName
        actionsVC.setActionEnabled(deleteEnabled, atIndex: 0)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override func updateColors() {
        super.updateColors()
        textFieldBackground.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()

            return baseHeight + confirmLabel.frame.height + 16 +
                textFieldBackground.frame.height + 16
                // keyboard should obscure the actions
                + max(
                    extraSpaceForKeyboard(cardContainer: cardContainerView),
                    actionsVC.tableView.contentSize.height + 16
                )
        }
        return baseHeight
    }
}

// MARK: - keyboard handling

extension DeleteProjectConfirmationCardViewController {
    /// Recalculate the `keyboardHeightInWindow` on keyboard frame change and update the card height
    @objc func keyboardWillChangeFrame(notification: NSNotification) {
        // Get required info out of the notification
        if let window = view.window,
           let cardDragging = cardDragging,
           let userInfo = notification.userInfo,
           let endRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? AnyObject)?.cgRectValue,
           let durationValue = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey],
           let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
        {
            // Calculate the height of the visible part of the keyboard
            keyboardHeightInWindow = window.frame.height - endRect.origin.y

            let duration = (durationValue as AnyObject).doubleValue
            let options = UIView.AnimationOptions(rawValue: UInt((curveValue as AnyObject).integerValue << 16))
            UIView.animate(withDuration: duration!, delay: 0, options: options, animations: {
                // update the card height
                cardDragging.setPosition(cardDragging.position, withVelocity: 0, animated: false)
            }, completion: nil)
        }
    }

    // subtract bottom safe area insets from keyboard as card dragging adds it to the card anyway
    func extraSpaceForKeyboard(cardContainer: UIView) -> CGFloat {
        max(keyboardHeightInWindow - cardContainer.safeAreaInsets.bottom, 0)
    }
}
