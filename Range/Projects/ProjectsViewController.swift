import Foundation
import OSLog
import RealmSwift
import SwiftUI
import UIKit

class ProjectsViewController: UIViewController {
    /// Model to access the current organization and projects
    let model: OrganizationModel
    let userPreferences: UserPreferences
    let userDataSyncState: UserDataSyncState
    let filters: ProjectFilters

    private var tableView: UITableView!
    private var emptyStateViewController: UIViewController?

    /// label shown as title view for navigation bar
    private let titleLabel = UILabel()

    private var currentUserNotificationToken: NotificationToken?
    private let createProjectButton = RoundShadowButton(
        image: UIImage(systemName: "plus") ?? UIImage(),
        imageTintColor: .white,
        variant: .blue
    )

    /// Default filters, never updated, for comparison of current filters output vs the default one for filters indicator badge
    private let defaultFilters: ProjectFilters
    private let filtersButton = RoundShadowButton(image: UIImage(named: "filter.search") ?? UIImage())
    private let filtersIndicatorBadge = BadgeView()

    var onProjectSelected: ((ProjectSummary) -> Void)?
    var onOrganizationButtonTap: (() -> Void)?
    var onSettingsButtonTap: (() -> Void)?
    var onViewWillAppear: (() -> Void)?

    /// Token for observing changes in projects
    private var notificationToken: NotificationToken?
    private var organizationNotificationToken: NotificationToken?

    let searchController = UISearchController()

    /// current organization projects sorted by name, optional as there might be no organization
    let projects: Results<ProjectSummary>

    /// Calculated from user search term input, this is what is actually applied to projects.
    /// It's an array of case/diactric insensitive and trimmed components of the search term
    /// If empty then it counts as matched.
    private var searchTerms: [String] = []
    // projects after applying fitlers
    private var filteredProjects: [ProjectSummary] = []
    // projects after applying fitlers and searchTerm
    private var searchedProjects: [ProjectSummary] = []

    private var recentProjects: [ProjectSummary] = []

    init(
        model: OrganizationModel,
        userPreferences: UserPreferences,
        userDataSyncState: UserDataSyncState,
        filters: ProjectFilters
    ) {
        self.model = model
        self.userPreferences = userPreferences
        self.userDataSyncState = userDataSyncState
        self.filters = filters
        defaultFilters = ProjectFilters()
        projects = model.projects.sorted(by: \.name)
        super.init(nibName: nil, bundle: nil)

        updateData()
        updateRecentProjects()
        NotificationCenter.default.addObserver(
            self, selector: #selector(filtersUpdated),
            name: ProjectFilters.UpdateNotificationName, object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        currentUserNotificationToken?.invalidate()
        notificationToken?.invalidate()
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

        setupOrganizationSelectorButton()
        setupRightBarButtonItems()
        setupTitleView()
        updateTitleLabel()
        setupCreateProjectButton()
        setupFiltersButton()
        setupFiltersIndicatorBadge()

        observeCurrentUser()
        observeOrganization()
        observeProjects()
        tableView.reloadData()
        updateEmptyStateView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // reload the recent projects (we may be back from a project so the recent list may have changed)
        updateRecentProjects()
        tableView.reloadData()

        analytics?._trackOrganizationEvent(name: "organization projects viewed", model, [
            "projectsActiveCount": model.projects.filter { $0.isArchived == false }.count,
            "projectsArchiveCount": model.projects.filter { $0.isArchived == true }.count
        ])

        onViewWillAppear?()
    }

    private func observeCurrentUser() {
        currentUserNotificationToken = model.currentUser.observe { [weak self] _ in
            self?.updateButtonsState()
            self?.tableView.reloadData()
        }
    }

    private func observeOrganization() {
        organizationNotificationToken = model.organization.observe { [weak self] _ in
            self?.updateEmptyStateView()
        }
    }

    private func observeProjects() {
        notificationToken?.invalidate()
        notificationToken = projects.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updateData()
                self.updateTitleLabel()
                self.updateEmptyStateView()
                self.updateFiltersIndicatorBadge()
            case .update:
                self.updateData()
                self.updateTitleLabel()
                self.updateEmptyStateView()
                self.updateFiltersIndicatorBadge()
            case let .error(error):
                Logger.model.error("observing projects failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func updateRecentProjects() {
        recentProjects = userPreferences.recentProjectIds(forOrganizationId: model.organizationId)
            .compactMap { projectId in
                filteredProjects.first { $0.id == projectId }
            }
    }

    @objc private func filtersUpdated() {
        updateData()
        updateTitleLabel()
        updateFiltersIndicatorBadge()
    }

    /// apply the search terms to filter the projects and reload the table view
    private func updateData() {
        filteredProjects = projects.filter(filters.match)

        searchedProjects = filteredProjects.filter(matchSearchTerms)

        updateRecentProjects()

        if tableView != nil {
            tableView.reloadData()
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
        tableView.register(ProjectTableViewHeaderCell.self, forCellReuseIdentifier: "HeaderCell")
        tableView.register(ProjectTableViewCell.self, forCellReuseIdentifier: "ProjectCell")
    }

    private func setupCreateProjectButton() {
        createProjectButton.addTarget(
            nil,
            action: #selector(ProjectsFlowActions.createProjectAction),
            for: .touchUpInside
        )
        view.addSubview(createProjectButton)
        createProjectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
    }

    private func setupFiltersButton() {
        filtersButton.addTarget(self, action: #selector(projectFiltersButtonTapped), for: .touchUpInside)
        view.addSubview(filtersButton)
        filtersButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            if model.currentUser.canCreateProject() {
                make.bottom.equalTo(createProjectButton.snp.top).offset(-12)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-12)
            }
        }
    }

    private func setupFiltersIndicatorBadge() {
        filtersIndicatorBadge.backgroundColor = .systemGreen
        filtersIndicatorBadge.contentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        filtersIndicatorBadge.textColor = .Neutral_10
        filtersIndicatorBadge.font = .systemFont(ofSize: 11, weight: .bold)
        filtersIndicatorBadge.isUserInteractionEnabled = false
        filtersButton.addSubview(filtersIndicatorBadge)
        filtersIndicatorBadge.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(16)
            make.centerY.equalToSuperview().offset(-16)
        }
    }

    /// Show filters indicator badge only if the number of items filtered by the current filter is different than the number
    /// of items filtered by the default filter
    private func updateFiltersIndicatorBadge() {
        let filteredCount = filteredProjects.count

        let filteredByDefaultFilterCount = projects.filter(defaultFilters.match).count

        // don't show the indicator if filter is not impacting the visible tasks
        filtersIndicatorBadge.isHidden = filteredCount == filteredByDefaultFilterCount

        filtersIndicatorBadge.text = filteredCount >= 99 ? "99+" : String(filteredCount)
    }

    @objc private func projectFiltersButtonTapped() {
        UIApplication.shared.sendAction(#selector(ProjectsFlowActions.selectProjectFiltersAction),
                                        to: nil, from: filtersButton, for: nil)
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

        title.append(NSAttributedString(string: " (\(filteredProjects.count))", attributes: [
            .foregroundColor: UIColor.dynamic(.Neutral_05),
            .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
        ]))

        titleLabel.attributedText = title
    }

    private func updateEmptyStateView() {
        guard !model.currentUser.isInvalidated else { return }

        if let emptyStateViewController {
            remove(childController: emptyStateViewController)
        }

        if model.organization.isBlockedDueToBillingError {
            tabBarController?.tabBar.isHidden = true
            navigationItem.searchController = nil
            navigationItem.titleView?.isHidden = true
            tableView.isHidden = true
            createProjectButton.isHidden = true
            let emptyStateView = OrganizationBlockedDueToBillingError(
                isCardDeclinedBillingError: model.organization.isCardDeclinedBillingError,
                userOrganizationRole: model.currentUser.organizationRole
            )
            emptyStateViewController = UIHostingController(rootView: emptyStateView)
            add(childController: emptyStateViewController!)
            emptyStateViewController!.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else if model.organization.isDisabled {
            tabBarController?.tabBar.isHidden = true
            navigationItem.searchController = nil
            navigationItem.titleView?.isHidden = true
            tableView.isHidden = true
            createProjectButton.isHidden = true
            let emptyStateView = OrganizationDisabledView(organizationName: model.organization.name)
            emptyStateViewController = UIHostingController(rootView: emptyStateView)
            add(childController: emptyStateViewController!)
            emptyStateViewController!.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else if projects.isEmpty {
            tabBarController?.tabBar.isHidden = true
            navigationItem.searchController = nil
            navigationItem.titleView?.isHidden = false
            tableView.isHidden = true
            createProjectButton.isHidden = true

            let emptyState: ProjectsEmptyStateView.State = model.currentUser.organizationRole == .Admin
                ? .noProjectsAdmin
                : .noProjectsCollaborator
            let emptyStateView = ProjectsEmptyStateView(state: emptyState, createProjectAction: { [weak self] in
                UIApplication.shared.sendAction(
                    #selector(ProjectsFlowActions.createProjectAction),
                    to: nil,
                    from: self,
                    for: nil
                )
            })
            emptyStateViewController = UIHostingController(rootView: emptyStateView)
            add(childController: emptyStateViewController!)
            emptyStateViewController!.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            tabBarController?.tabBar.isHidden = false
            navigationItem.searchController = searchController
            navigationItem.titleView?.isHidden = false
            tableView.isHidden = false
            createProjectButton.isHidden = !model.currentUser.canCreateProject()
        }
    }

    private func updateButtonsState() {
        createProjectButton.isHidden = !model.currentUser.canCreateProject()
        filtersButton.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            if model.currentUser.canCreateProject() {
                make.bottom.equalTo(createProjectButton.snp.top).offset(-12)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-12)
            }
        }
    }

    private func setupOrganizationSelectorButton() {
        let button = RangeButton(
            configuration: .organizationSelector(model.organization),
            primaryAction: UIAction { [weak self] _ in self?.onOrganizationButtonTap?() }
        )
        .withCustomRangeHighlightColor()

        button.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
        button.tapAreaInsets = UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4)

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
    }

    private func setupRightBarButtonItems() {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamic(.Neutral_04)
        let button = RangeButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(
                systemName: "gearshape",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
            )) { [weak self] _ in
                self?.onSettingsButtonTap?()
            }
        )
        button.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        let dataSyncIndicatorView = DataSyncIndicatorView(userDataSyncState)
        dataSyncIndicatorView.onTapped = { [weak self] in
            guard let self else { return }
            _dataSyncInfoCard(self.userDataSyncState.state).installAndShowCard(in: self._rootViewController())
        }

        let billingErrorInticatorView = BillingErrorIndicatorView(model.organization)
        billingErrorInticatorView.onTapped = { [weak self] in
            guard let self else { return }
            OrganizationBillingErrorCardViewController(self.model).installAndShowCard(in: self._rootViewController())
        }
        
        let itemsStack = UIStackView.init(arrangedSubviews: [billingErrorInticatorView, dataSyncIndicatorView, button])
        itemsStack.distribution = .equalSpacing
        itemsStack.axis = .horizontal
        itemsStack.alignment = .center
        itemsStack.spacing = 0
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: itemsStack)
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
        if searchTerms.isEmpty {
            // showing recent and all projects but only if there are any recent projects
            if recentProjects.isEmpty {
                // can happen when user is removed from a project before the table is reloaded
                guard row < filteredProjects.count else { return .header("") }
                return .project(filteredProjects[row])
            } else {
                if row == 0 {
                    return .header(String(localized: "Recent Projects"))
                } else if row <= recentProjects.count {
                    guard row - 1 < recentProjects.count else { return .header("") }
                    return .project(recentProjects[row - 1])
                } else if row == recentProjects.count + 1 {
                    return .header(String(localized: "All Projects (A-Z)"))
                } else {
                    guard row - recentProjects.count - 2 < filteredProjects.count else { return .header("") }
                    return .project(filteredProjects[row - recentProjects.count - 2])
                }
            }
        } else {
            // showing search results only
            guard row < searchedProjects.count else { return .header("") }
            return .project(searchedProjects[row])
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        if searchTerms.isEmpty {
            // showing recent and all projects but only if there are any recent projects
            if recentProjects.isEmpty {
                return filteredProjects.count
            } else {
                // (+1 for each header), as it's all rendered as cells (each project row is a separate
                // section to get a rounded cell layout
                return 1 + recentProjects.count + 1 + filteredProjects.count
            }

        } else {
            // showing search results only
            return searchedProjects.count
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
            cell.setProject(project, model: model)
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
                selectedBackgroundColor: .dynamic(.Neutral_08)
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
    }

    /// Project matches if its name contains all the searchTerms
    func matchSearchTerms(project: ProjectSummary) -> Bool {
        guard !searchTerms.isEmpty else { return true }
        let name = project.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return searchTerms.allSatisfy { name.contains($0) }
    }
}
