import Foundation
import OSLog
import Realm
import RealmSwift
import UIKit

/// Card view controller presenting sample text in all available fonts.
/// Used to compare available font sizes with what's been implemented & test accessibility scaling
///
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class TypeScaleCardViewController: SheetCardViewController {
    private let headerView = UIView()
    private var weightToggle: SegmentedControl!
    private let headerStroke = UIView()

    private let textStyles: [UIFont.TextStyle] = [
        .caption2,
        .caption1,
        .footnote,
        .subheadline,
        .callout,
        .body,
        .headline,
        .title3,
        .title2,
        .title1,
        .largeTitle,
    ]
    private let tableView = UITableView(frame: .zero, style: .plain)

    /// Initializer
    ///
    init() {
        super.init(icon: UIImage(systemName: "textformat.size"), title: String(localized: "Type Scale"))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderView()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(48)
        }

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: headerView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        updateTitle()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()

        updateTitle()
    }

    private func updateTitle() {
        titleLabel?.text = String(localized: "Type Scale") +
            " - " + traitCollection.preferredContentSizeCategory._displayName
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }

    private func setupHeaderView() {
        headerView.backgroundColor = view.backgroundColor

        weightToggle = SegmentedControl(items: [
            ActionItem(
                title: String(localized: "Default"),
                handler: { [weak self] in
                    self?.tableView.reloadData()
                }
            ),
            ActionItem(
                title: String(localized: "Bold"),
                handler: { [weak self] in
                    self?.tableView.reloadData()
                }
            ),
        ])
        headerView.addSubview(weightToggle)
        weightToggle.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(SegmentedControl.height)
        }

        headerStroke.backgroundColor = .dynamic(.Neutral_07)
        headerView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(TypeScaleTableViewCell.self, forCellReuseIdentifier: "TypeScaleCell")
        tableView.keyboardDismissMode = .onDrag
    }
}

// MARK: table view delegate

extension TypeScaleCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        textStyles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TypeScaleCell",
                                                 for: indexPath) as! TypeScaleTableViewCell
        cell.setTextStyle(textStyles[indexPath.row], bold: weightToggle.selectedSegmentIndex == 1)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
