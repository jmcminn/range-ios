import Foundation
import UIKit

/// Card view controller presenting a list of statuses to choose from.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class StatusPickerCardViewController: SheetCardViewController {
    let statuses: [Status]
    private let selectedStatus: Status?
    private let tableView = UITableView(frame: .zero, style: .plain)

    var onStatusPicked: ((Status) -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                         title of the card
    ///     - statuses:                 statuses to show in the picker
    init(title: String, statuses: [Status], selectedStatus: Status?, onStatusPicked: ((Status) -> Void)? = nil) {
        self.statuses = statuses
        self.selectedStatus = selectedStatus
        super.init(icon: nil, title: title)
        self.onStatusPicked = onStatusPicked
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        tableView.reloadData()
        containerView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(12)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(StatusTableViewCell.self, forCellReuseIdentifier: "StatusCell")
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
            return baseHeight + tableView.contentSize.height + 12.0
        }
        return baseHeight
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }
}

extension StatusPickerCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        statuses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatusCell", for: indexPath) as! StatusTableViewCell
        let status = statuses[indexPath.row]
        cell.setStatus(status, selected: status == selectedStatus)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamic(.Neutral_09),
            borderColor: .dynamic(.Neutral_07),
            selectedBackgroundColor: .systemGray4 // this is what selectedBackgroundView uses by default
        )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let status = statuses[indexPath.row]
        dismissCard()
        onStatusPicked?(status)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
}
