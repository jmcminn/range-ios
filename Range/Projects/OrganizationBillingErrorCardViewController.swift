import UIKit

class OrganizationBillingErrorCardViewController: SheetCardViewController {
    private let bgView = UIView()
    private let label = UILabel()
    private let questionsLabel = UILabel()
    private let contactUsButton: UIButton?

    init(_ model: OrganizationModel) {
        let organization = model.organization!
        let title = if organization.isCardDeclinedBillingError {
            "Account Billing Issue"
        } else {
            "Billing Issue Identified"
        }
        if !organization.isCardDeclinedBillingError, model.currentUser.organizationRole == .Admin {
            contactUsButton = RangeButton(
                configuration: UIButton.Configuration.blueButton(),
                primaryAction: UIAction(title: "Contact Us") { _ in
                    guard let url = URL(string: "mailto:support@range.io") else { return }
                    UIApplication.shared.open(url)
                }
            ).withCustomRangeHighlightColor()
        } else {
            contactUsButton = nil
        }
        super.init(
            icon: UIImage(systemName: "exclamationmark.triangle"),
            title: title
        )

        let daysRemainingString: String
        if let gracePeriodEnd = organization.billingErrorGracePeriodEnd {
            let daysRemainingInt = max(0, Calendar.current._daysAgo(from: Date(), to: gracePeriodEnd) ?? 0)
            daysRemainingString = " (\(daysRemainingInt) \(daysRemainingInt == 1 ? "day" : "days") remaining)"
        } else {
            daysRemainingString = ""
        }
        label.text = if organization.isCardDeclinedBillingError {
            model.currentUser.organizationRole == .Admin
                ?
                "Your Range account has a billing issue. Please update the payment details to maintain access to your team’s data.\(daysRemainingString)"
                :
                "Your Range account has a billing issue. Please have a Range Admin update the payment details to maintain access to your team’s data.\(daysRemainingString)"
        } else {
            "We’ve identified a critical billing issue that needs to be resolved for the \(organization.name) Organization to continue using Range.\(daysRemainingString)"
        }

        let questionsLabelText = NSMutableAttributedString(string: "Questions? Contact us at ",
                                                           attributes: [.foregroundColor: UIColor.dynamic(.Neutral_05)])
        let supportString = NSAttributedString(string: "support@range.io", attributes: [
            .foregroundColor: UIColor.Primary_Blue_04,
        ])
        questionsLabelText.append(supportString)
        questionsLabel.attributedText = questionsLabelText
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bgView.layer.cornerRadius = 8
        bgView.backgroundColor = .dynamic(.Neutral_09)
        bgView.layer.borderWidth = 1
        containerView.addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sheetHeaderView.snp.bottom)
        }

        label.textColor = .dynamic(.Neutral_04)
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true

        bgView.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        questionsLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        questionsLabel.numberOfLines = 0
        questionsLabel.lineBreakMode = .byWordWrapping
        questionsLabel.adjustsFontForContentSizeCategory = true
        questionsLabel.isUserInteractionEnabled = true
        questionsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(supportTap)))
        containerView.addSubview(questionsLabel)
        questionsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(bgView.snp.bottom).offset(12)
        }
        
        if let contactUsButton {
            containerView.addSubview(contactUsButton)
            contactUsButton.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.top.equalTo(questionsLabel.snp.bottom).offset(12)
            }
        }

        updateColors()
    }

    override func updateColors() {
        super.updateColors()

        bgView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()

            var height = baseHeight + 16 + bgView.frame.height + 12 + questionsLabel.frame.height
            
            if let contactUsButton {
                height += 12 + contactUsButton.frame.height
            }

            return height
        }
        return baseHeight
    }

    @objc func supportTap() {
        guard let url = URL(string: "mailto:support@range.io") else { return }
        UIApplication.shared.open(url)
    }
}
