import UIKit

class OrganizationLimitsCardViewController: SheetCardViewController {
    private let bgView = UIView()
    private let label = UILabel()
    private let contactUsButton: UIButton?

    init(_ limitsAndCounts: OrganizationLimitsAndCounts) {
        let planString = limitsAndCounts.organization?.plan ?? "Free"
        if planString == "Free" {
            contactUsButton = nil
        } else {
            contactUsButton = RangeButton(
                configuration: UIButton.Configuration.blueButton(),
                primaryAction: UIAction(title: "Contact Us") { _ in
                    guard let url = URL(string: "mailto:support@range.io") else { return }
                    UIApplication.shared.open(url)
                }
            ).withCustomRangeHighlightColor()
        }

        super.init(
            icon: UIImage(systemName: "exclamationmark.triangle"),
            title: "\(limitsAndCounts.organization?.plan ?? "Organization") Plan Limits Reached"
        )

        let text =
            NSMutableAttributedString(
                string: "Your Organization has reached the limits of the \(planString) plan on Range."
            )

        let tapHere = NSAttributedString(string: " Tap here ", attributes: [
            .link: URL(string: "https://range.app")!,
            .foregroundColor: UIColor.Primary_Blue_04,
        ])
        text.append(tapHere)
        text.append(NSAttributedString(string: "to see what’s included in your \(planString) plan, "))
        text.append(NSAttributedString(string:
            planString == "Free"
                ? "or upgrade to a paid Team plan through the web desktop version of the Range app."
                : "or contact us to upgrade to an Enterprise plan."))
        label.attributedText = text
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
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHere)))

        bgView.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        if let contactUsButton {
            containerView.addSubview(contactUsButton)
            contactUsButton.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.top.equalTo(bgView.snp.bottom).offset(12)
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

            var height = baseHeight + 16 + bgView.frame.height

            if let contactUsButton {
                height += 12 + contactUsButton.frame.height
            }

            return height
        }
        return baseHeight
    }

    @objc func tapHere() {
        guard let url = URL(string: "https://range.io") else { return }
        UIApplication.shared.open(url)
    }
}
