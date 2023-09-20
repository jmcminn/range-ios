import Foundation
import SnapKit
import UIKit

class StringPickerCardViewController: SheetCardViewController {
    private let strings: [String]
    private var selectedString: String?
    private let tableView = UITableView(frame: .zero, style: .plain)

    var onStringSelected: ((String) -> Void)?

    init(title: String, strings: [String], selectedString: String?) {
        self.strings = strings
        self.selectedString = selectedString
        super.init(icon: nil, title: title)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        // distance between first section (the rest is covered by sections footers)
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(StringPickerTableViewCell.self, forCellReuseIdentifier: "StringCell")
        tableView.keyboardDismissMode = .onDrag
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

// MARK: - table view delegate / data source

extension StringPickerCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        strings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StringCell",
                                                 for: indexPath) as! StringPickerTableViewCell
        let value = strings[indexPath.row]
        cell.setValue(value, selected: value == selectedString)
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
        let value = strings[indexPath.row]
        dismissCard()
        onStringSelected?(value)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        // distance between sections
        16
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }
}
