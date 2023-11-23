import Foundation
import UIKit

/// Card view controller presenting a list of organizations to choose from.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class OrganizationSelectorCardViewController: SheetCardViewController {
    let organizations: [Organization]
    private let selectedOrganization: Organization?
    private let tableView = UITableView(frame: .zero, style: .plain)

    var onOrganizationSelected: ((Organization) -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                         title of the card
    ///     - canvases:               canvases to show in the selector
    init(
        organizations: [Organization],
        selectedOrganization: Organization?,
        onOrganizationSelected: ((Organization) -> Void)? = nil
    ) {
        self.organizations = organizations
        self.selectedOrganization = selectedOrganization
        super.init(icon: nil, title: String(localized: "My Organizations"))
        self.onOrganizationSelected = onOrganizationSelected
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        setupTableView()
        tableView.reloadData()
        containerView.insertSubview(tableView, belowSubview: sheetHeaderView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(OrganizationTableViewCell.self, forCellReuseIdentifier: "OrganizationCell")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + tableView.contentSize.height + 16.0
        }
        return baseHeight
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }
}

extension OrganizationSelectorCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        // each organization in separate section to have rounded cells per org
        organizations.count
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "OrganizationCell",
            for: indexPath
        ) as! OrganizationTableViewCell
        let organization = organizations[indexPath.section]
        cell.setOrganization(organization, selected: organization == selectedOrganization)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let organization = organizations[indexPath.section]
        let selected = organization == selectedOrganization
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: selected ? .dynamic(.Neutral_08) : .dynamic(.Neutral_09),
            borderColor: selected ? .Primary_Blue_04 : .dynamic(.Neutral_07),
            selectedBackgroundColor: .dynamic(.Neutral_08)
        )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let organization = organizations[indexPath.section]
        dismissCard()
        onOrganizationSelected?(organization)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        16
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }
}
