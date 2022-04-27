import FirebaseCrashlytics
import SnapKit
import UIKit

/// Helper class for definining actions displayed by ``ProjectActionSelectorViewController``
class ProjectAction {
    /// Short display title.
    let title: String?
    /// image systemName
    let imageName: String?
    /// action to be performed
    let handler: (() -> Void)?
    init(title: String? = nil, imageName: String? = nil, handler: (() -> Void)? = nil) {
        self.title = title
        self.imageName = imageName
        self.handler = handler
    }
}

class ProjectActionSelectorViewController: UIViewController {
    var tableView: UITableView!
    let actions: [ProjectAction]

    private let imageConfig = UIImage.SymbolConfiguration(textStyle: .subheadline)
        .applying(UIImage.SymbolConfiguration(weight: .medium))

    /// Initiates with additional actions to show (besides the default ones)
    /// - Parameters:
    ///   - actions: array of actions
    init(actions: [ProjectAction] = []) {
        self.actions = actions + [
            ProjectAction(title: "Activity Feed", imageName: "calendar.day.timeline.left", handler: {
//                Crashlytics.crashlytics().log("I think I'm gonna crash now!")
//                let numbers = [0]
//                _ = numbers[1]
            }),
            ProjectAction(title: "All Media", imageName: "photo"),
            ProjectAction(title: "Photo Collections", imageName: "photo.on.rectangle.angled"),
            ProjectAction(title: "Collaborations", imageName: "mappin"),
            ProjectAction(title: "Features", imageName: "mappin.and.ellipse"),
        ]
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        view.addSubview(tableView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.Neutral_10

        tableView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorInset = .zero
        tableView.separatorInsetReference = .fromCellEdges
        tableView.separatorColor = UIColor.Neutral_08
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActionCell")

        tableView.reloadData()
//        tableView.invalidateIntrinsicContentSize()
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension ProjectActionSelectorViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        actions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath)
        cell.backgroundColor = UIColor.Neutral_09
        cell.imageView?.tintColor = UIColor.Neutral_04
        cell.textLabel?.textColor = UIColor.Neutral_04
        let action = actions[indexPath.row]
        cell.textLabel?.text = action.title
        if let imageName = action.imageName {
            cell.imageView?.image = UIImage(systemName: imageName, withConfiguration: imageConfig)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
