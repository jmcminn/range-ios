import UIKit

class OrganizationLimitsCardViewController: SheetCardViewController {
    private let bgView = UIView()
    private let label = UILabel()

    init(_ limitsAndCounts: OrganizationLimitsAndCounts) {
        super.init(
            icon: UIImage(systemName: "exclamationmark.triangle"),
            title: "\(limitsAndCounts.organization?.plan ?? "Organization") Plan Limits Reached"
        )
        let planString = limitsAndCounts.organization?.plan?.lowercased() ?? "free"
        label.text =
            "Your Organization has reached the limits of the \(planString) plan on Range. Use a web browser to visit Range.io to compare and upgrade your Range plan."
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

            return baseHeight + 16 + bgView.frame.height
        }
        return baseHeight
    }
}
