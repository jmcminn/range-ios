import UIKit

class OrganizationBillingErrorCardViewController: SheetCardViewController {
    private let bgView = UIView()
    private let label = UILabel()
    private let questionsLabel = UILabel()

    init(_ model: OrganizationModel) {
        super.init(
            icon: UIImage(systemName: "exclamationmark.triangle"),
            title: "Account Billing Issue"
        )

        let daysRemainingString: String
        if let gracePeriodEnd = model.organization.billingErrorGracePeriodEnd {
            let daysRemainingInt = max(0, Calendar.current._daysAgo(from: Date(), to: gracePeriodEnd) ?? 0)
            daysRemainingString = " (\(daysRemainingInt) \(daysRemainingInt == 1 ? "day" : "days") remaining)"
        } else {
            daysRemainingString = ""
        }
        label.text = model.currentUser.organizationRole == .Admin
            ?
            "Your Range account has a billing issue. Please update the payment details to maintain access to your team’s data.\(daysRemainingString)"
            :
            "Your Range account has a billing issue. Please have a Range Admin update the payment details to maintain access to your team’s data.\(daysRemainingString)"

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

            return baseHeight + 16 + bgView.frame.height + 12 + questionsLabel.frame.height
        }
        return baseHeight
    }

    @objc func supportTap() {
        guard let url = URL(string: "mailto:support@range.io") else { return }
        UIApplication.shared.open(url)
    }
}
