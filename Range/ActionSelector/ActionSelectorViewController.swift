import FirebaseCrashlytics
import SnapKit
import UIKit

/// View controller presenting given array of `ActionItem` in a table view
class ActionSelectorViewController: UIViewController {
    var tableView: UITableView!
    let actions: [ActionItem]

    private let imageConfig = UIImage.SymbolConfiguration(textStyle: .caption1)
        .applying(UIImage.SymbolConfiguration(weight: .medium))

    /// Initiates with actions to show
    /// - Parameters:
    ///   - actions: array of actions
    init(actions: [ActionItem]) {
        self.actions = actions
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

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActionCell")

        tableView.reloadData()
//        tableView.invalidateIntrinsicContentSize()
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the border color for cells
        tableView.reloadData()
    }
}

extension ActionSelectorViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        actions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath)
        let action = actions[indexPath.row]

        cell.backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:
        let actionColor: UIColor = action.style == .destructive
            ? .Red_03
            : .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        cell.imageView?.tintColor = actionColor
        cell.textLabel?.textColor = actionColor
        cell.textLabel?.text = action.title
        if let imageName = action.imageName {
            cell.imageView?.image = UIImage(systemName: imageName, withConfiguration: imageConfig)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamicColor(light: .Neutral_02, dark: .Neutral_09),
            borderColor: .dynamicColor(light: .Neutral_03, dark: .Neutral_08),
            selectedBackgroundColor: .systemGray4 // this is what selectedBackgroundView uses by default
        )
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let action = actions[indexPath.row]
        action.handler?()
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
}
