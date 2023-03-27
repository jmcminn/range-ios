import Foundation
import OSLog
import Realm
import RealmSwift
import UIKit

class ProjectsViewController: UIViewController {
    /// projects to show
    private let projects: Results<ProjectSummary>
    private var tableView: UITableView!

    /// label shown as title view for navigation bar
    private let titleLabel = UILabel()

    var onProjectSelected: ((ProjectSummary) -> Void)?

    /// Token for observing changes in projects
    private var notificationToken: NotificationToken?

    init(projects: Results<ProjectSummary>) {
        self.projects = projects

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_10)

        setupTableView()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.reloadData()

        setupTitleView()
        updateTitleLabel()

        observeProjects()
    }

    private func observeProjects() {
        notificationToken = projects.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.tableView.reloadData()
                self.updateTitleLabel()
            case .update:
                self.tableView.reloadData()
                self.updateTitleLabel()
            case let .error(error):
                Logger.model.error("observing projects failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the border color for cells
        tableView.reloadData()
        updateTitleLabel()
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(ProjectTableViewCell.self, forCellReuseIdentifier: "ProjectCell")
    }

    /// Setup custom navigationItem.titleView with UILabel subview so we can set attributedText for title
    private func setupTitleView() {
        let titleView = UIView()
        titleView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview()
        }

        navigationItem.titleView = titleView
        titleView.snp.makeConstraints { make in
            // make it any height, otherwise it's not layed out properly
            make.height.equalTo(80)
        }
    }

    private func updateTitleLabel() {
        let title = NSMutableAttributedString(string: "My Projects", attributes: [
            .foregroundColor: UIColor.dynamicColor(light: .Neutral_07, dark: .Neutral_04),
            // .body in the design, but it gets too large when scaling font
            .font: UIFont._preferredFont(forTextStyle: .headline, symbolicTraits: .traitBold),
        ])

        title.append(NSAttributedString(string: " (\(projects.count))", attributes: [
            .foregroundColor: UIColor.dynamicColor(light: .Neutral_06, dark: .Neutral_05),
            .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
        ]))

        titleLabel.attributedText = title
    }
}

extension ProjectsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        projects.count
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        // 1 project per section as we want each project row to be separated from other rows
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "ProjectCell",
            for: indexPath
        ) as! ProjectTableViewCell
        let project = projects[indexPath.section]
        cell.setProject(project)
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
        guard indexPath.section < projects.count else { return }
        let project = projects[indexPath.section]
        onProjectSelected?(project)
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
