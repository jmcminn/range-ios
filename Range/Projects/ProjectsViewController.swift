import Foundation
import OSLog
import Realm
import RealmSwift
import SwiftUI
import UIKit

class ProjectsViewController: UIViewController {
    /// Model to access the current organization and projects
    unowned let model: ProjectsModel

    /// To observe changes in model.currentOrganization
    private var currentOrganizationObservation: NSKeyValueObservation?

    private var tableView: UITableView!
    private var emptyStateViewController: UIHostingController<ProjectsEmptyStateView>?

    /// label shown as title view for navigation bar
    private let titleLabel = UILabel()

    var onProjectSelected: ((ProjectSummary) -> Void)?
    var onOrganizationButtonTap: (() -> Void)?

    /// Token for observing changes in projects
    private var notificationToken: NotificationToken?

    let searchController = UISearchController()

    /// current organization projects sorted by name, optional as there might be no organization
    private var projects: Results<ProjectSummary>?

    /// Calculated from user search term input, this is what is actually applied to projects.
    /// It's an array of case/diactric insensitive and trimmed components of the search term
    /// If empty then it counts as matched.
    private var searchTerms: [String] = []
    private var filteredProjects: [ProjectSummary] = []

    private var recentProjects: [ProjectSummary] = []

    init(model: ProjectsModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)

        currentOrganizationObservation = model.observe(\.currentOrganization) { [weak self] _, _ in
            self?.onOrganizationChange()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        notificationToken?.invalidate()
        currentOrganizationObservation?.invalidate()
    }

    private func onOrganizationChange() {
        // guard so it's not called too fast
        guard tableView != nil else { return }

        if let organization = model.currentOrganization {
            let projects = organization.projects.where { $0.placeholder == false }.sorted(by: \.name)
            filteredProjects = [ProjectSummary](projects)
            recentProjects = UserDefaults.recentProjectIds(forOrganizationId: organization.id).compactMap { projectId in
                projects.first { $0.id == projectId }
            }
            self.projects = projects
            observeProjects()
        } else {
            projects = nil
            filteredProjects = []
            recentProjects = []
        }

        tableView.reloadData()

        updateEmptyStateView()
        updateTitleLabel()
        updateProjectSelectorButton()

        if model.currentOrganization != nil {
            navigationItem.searchController = searchController
        } else {
            navigationItem.searchController = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: String(localized: "Search for projects"),
            attributes: [.foregroundColor: UIColor.dynamic(.Neutral_05)]
        )
        searchController.searchResultsUpdater = self

        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController

        view.backgroundColor = .dynamic(.Neutral_10)

        setupTableView()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupTitleView()

        onOrganizationChange()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // reload the recent projects (we may be back from a project so the recent list may have changed)
        if let organization = model.currentOrganization {
            recentProjects = UserDefaults.recentProjectIds(forOrganizationId: organization.id).compactMap { projectId in
                organization.projects.first { $0.id == projectId }
            }
        } else {
            recentProjects = []
        }
        tableView.reloadData()
    }

    private func observeProjects() {
        notificationToken?.invalidate()
        guard let projects = projects else { return }
        notificationToken = projects.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updateData()
                self.updateTitleLabel()
                self.updateEmptyStateView()
            case .update:
                self.updateData()
                self.updateTitleLabel()
                self.updateEmptyStateView()
            case let .error(error):
                Logger.model.error("observing projects failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// apply the search terms to filter the projects and reload the table view
    private func updateData() {
        filteredProjects = projects?.filter(matchSearchTerms) ?? []

        tableView.reloadData()
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
        tableView.register(ProjectTableViewHeaderCell.self, forCellReuseIdentifier: "HeaderCell")
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
            .foregroundColor: UIColor.dynamic(.Neutral_04),
            // .body in the design, but it gets too large when scaling font
            .font: UIFont._preferredFont(forTextStyle: .headline, symbolicTraits: .traitBold),
        ])

        if let projects = projects {
            title.append(NSAttributedString(string: " (\(projects.count))", attributes: [
                .foregroundColor: UIColor.dynamic(.Neutral_05),
                .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
            ]))
        }

        titleLabel.attributedText = title
    }

    private func updateEmptyStateView() {
        var newState: ProjectsEmptyStateView.State?
        if model.currentOrganization == nil {
            newState = .noOrganization
        } else if projects == nil || projects!.isEmpty {
            // TODO: 1717 need org participant...
        }

//        emptyStateViewController?.view.removeFromSuperview()
//            emptyStateViewController = UIHostingController(rootView: ProjectsEmptyStateView(state: .noOrganization))
    }

    private func updateProjectSelectorButton() {
        guard let organization = model.currentOrganization else {
            navigationItem.leftBarButtonItem = nil
            return
        }

        var config = UIButton.Configuration.filled()
        config.contentInsets = .zero
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_05)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 16
        config.background.strokeColor = .dynamic(.Neutral_07)
        let button = ButtonWithTapAreaInsets(
            configuration: config,
            primaryAction: UIAction(title: String(organization.name.prefix(1).uppercased())) { [weak self] _ in
                self?.onOrganizationButtonTap?()
            }
        )
        button.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
        button.tapAreaInsets = UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4)

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
    }
}

extension ProjectsViewController: UITableViewDelegate, UITableViewDataSource {
    /// Enum to describe a cell if it's a header of project cell (we need it because we use sections for rows to make them round)
    enum CellValue {
        case header(String)
        case project(ProjectSummary)
    }

    private func getCellValue(forRowAtIndexPath indexPath: IndexPath) -> CellValue {
        let row = indexPath.section
        guard let projects = projects else { fatalError("No organization set") }
        if searchTerms.isEmpty {
            // showing recent and all projects but only if there are any recent projects
            if recentProjects.isEmpty {
                return .project(projects[row])
            } else {
                if row == 0 {
                    return .header(String(localized: "Recent Projects"))
                } else if row <= recentProjects.count {
                    return .project(recentProjects[row - 1])
                } else if row == recentProjects.count + 1 {
                    return .header(String(localized: "All Projects (A-Z)"))
                } else {
                    return .project(projects[row - recentProjects.count - 2])
                }
            }
        } else {
            // showing search results only
            return .project(filteredProjects[row])
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        if searchTerms.isEmpty {
            guard let projects = projects else { return 0 }
            // showing recent and all projects but only if there are any recent projects
            if recentProjects.isEmpty {
                return projects.count
            } else {
                // (+1 for each header), as it's all rendered as cells (each project row is a separate
                // section to get a rounded cell layout
                return 1 + recentProjects.count + 1 + projects.count
            }

        } else {
            // showing search results only
            return filteredProjects.count
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        // 1 project per section as we want each project row to be separated from other rows
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellValue = getCellValue(forRowAtIndexPath: indexPath)
        switch cellValue {
        case let .header(name):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "HeaderCell",
                for: indexPath
            ) as! ProjectTableViewHeaderCell
            cell.setName(name)
            return cell
        case let .project(project):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "ProjectCell",
                for: indexPath
            ) as! ProjectTableViewCell
            cell.setProject(project)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if case .project = getCellValue(forRowAtIndexPath: indexPath) {
            // this should be considered a hack - there's no easy way of adding a border around the section in table view
            tableView.addBackgroundWithBorder(
                forCell: cell,
                forRowAt: indexPath,
                backgroundColor: .dynamic(.Neutral_09),
                borderColor: .dynamic(.Neutral_07),
                selectedBackgroundColor: .systemGray4 // this is what selectedBackgroundView uses by default
            )
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard case let .project(project) = getCellValue(forRowAtIndexPath: indexPath) else { return }
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

extension ProjectsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        // calculate search terms from user entered search text
        let textTrimmed = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let searchTerm = textTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        searchTerms = searchTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        updateData()

        print("Search terms: ", searchTerms)
    }

    /// Project matches if its name contains all the searchTerms
    func matchSearchTerms(project: ProjectSummary) -> Bool {
        guard !searchTerms.isEmpty else { return true }
        let name = project.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return searchTerms.allSatisfy { name.contains($0) }
    }
}
