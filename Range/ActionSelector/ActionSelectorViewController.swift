import SnapKit
import UIKit

/// View controller presenting given array of `ActionItem` in a table view
class ActionSelectorViewController: UIViewController {
    var tableView: UITableView!
    let actions: [[ActionItem]]
    // whether action at given index is enabled, true by default for all actions
    // this only works for now for 1 section case
    var actionsEnabled: [Bool]

    /// Initiates with actions to show
    /// - Parameters:
    ///   - actions: array of arrays of actions (each subarray is a section of actions)
    init(actions: [[ActionItem]]) {
        self.actions = actions
        self.actionsEnabled = actions[0].map { _ in true }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        // we use .plain style and the make it look like grouped because we need to add borders around section which grouped style doesn't support
        tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_10)

        tableView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        // border is now added manually to each cell:
//        tableView.separatorInset = .zero
//        tableView.separatorInsetReference = .fromCellEdges
//        tableView.separatorColor = UIColor.Neutral_08
        tableView.register(ActionItemTableViewCell.self, forCellReuseIdentifier: "ActionItemCell")

        tableView.reloadData()
//        tableView.invalidateIntrinsicContentSize()
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setActionEnabled(_ enabled: Bool, atIndex: Int) {
        actionsEnabled[atIndex] = enabled
        tableView.reloadData()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the border color for cells
        tableView.reloadData()
    }
}

extension ActionSelectorViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        actions.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        actions[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "ActionItemCell",
            for: indexPath
        ) as! ActionItemTableViewCell
        let action = actions[indexPath.section][indexPath.row]
        cell.setActionItem(action, enabled: actionsEnabled[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamic(.Neutral_09),
            borderColor: .dynamic(.Neutral_07),
            selectedBackgroundColor: .dynamic(.Neutral_08)
        )
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard actionsEnabled[indexPath.row] else { return }
        let action = actions[indexPath.section][indexPath.row]
        action.handler?()
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section < actions.count - 1 {
            24
        } else {
            CGFloat.leastNormalMagnitude
        }
    }
    
    func tableView(_: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section < actions.count - 1 {
            UIView()
        } else {
            nil
        }
    }

}
