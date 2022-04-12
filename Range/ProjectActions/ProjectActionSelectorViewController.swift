import SnapKit
import UIKit

class ProjectActionSelectorViewController: UIViewController {
    var tableView: UITableView!
    let actions: [UIAction]

    init() {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .subheadline)
            .applying(UIImage.SymbolConfiguration(weight: .medium))
        actions = [
            UIAction(
                title: "Activity Feed",
                image: UIImage(
                    systemName: "calendar.day.timeline.left",
                    withConfiguration: imageConfig
                ),
                handler: { _ in }
            ),
            UIAction(
                title: "All Media",
                image: UIImage(systemName: "photo", withConfiguration: imageConfig),
                handler: { _ in }
            ),
            UIAction(
                title: "Photo Collections",
                image: UIImage(
                    systemName: "photo.on.rectangle.angled",
                    withConfiguration: imageConfig
                ),
                handler: { _ in }
            ),
            UIAction(
                title: "Collaborations",
                image: UIImage(systemName: "mappin", withConfiguration: imageConfig),
                handler: { _ in }
            ),
            UIAction(
                title: "Features",
                image: UIImage(systemName: "mappin.and.ellipse", withConfiguration: imageConfig),
                handler: { _ in }
            ),
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
        cell.imageView?.image = action.image
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
}
