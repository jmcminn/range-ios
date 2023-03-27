import Foundation
import UIKit

/// Card view controller presenting a list of users to choose from.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class UserPickerCardViewController: SheetCardViewController {
    /// All users to display in picker
    let users: [Participant]
    /// for each user from `users` this array has a search string to be used when filtering the users (based on the first/last name and email)
    let searchStrings: [String]
    /// Users currently filtered by search term from search view (this array is used in the tableView)
    var filteredUsers: [Participant]
    private let selectedUser: Participant?

    // background view for searchView that has the headerStroke at the bottom, added so it can
    // have a shadow when scrolling the users
    private let headerView = UIView()
    private let searchView = SearchView(placeholderText: "Search for an assignee...", showClearButton: true)
    private let headerStroke = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    var onUserPicked: ((Participant?) -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                    title of the card
    ///     - users:                 users to show in the picker
    init(
        title: String,
        users: [Participant],
        selectedUser: Participant?,
        onUserPicked: ((Participant?) -> Void)? = nil
    ) {
        let firstNameSort = SortDescriptor(\Participant.firstName, comparator: .localizedStandard)
        let lastNameSort = SortDescriptor(\Participant.lastName, comparator: .localizedStandard)
        // users are sorted by first name and then last name
        self.users = users.sorted(using: [firstNameSort, lastNameSort])
        searchStrings = self.users.map {
            "\($0.firstName) \($0.lastName) \($0.email)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        }
        filteredUsers = self.users
        self.selectedUser = selectedUser
        super.init(icon: UIImage(systemName: "person"), title: title)
        self.onUserPicked = onUserPicked
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderVew()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }

        setupSearchView()
        headerView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
        }

        setupHeaderStroke()
        headerView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: headerView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
        updateHeaderShadow()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height (because we want to
            // show the keyboard for searching anyway, so no point in changing the card position
            // back and forth when showing/hiding the keyboard)
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }

    private func setupHeaderVew() {
        headerView.backgroundColor = .dynamic(.Neutral_10)
    }

    private func setupSearchView() {
        searchView.addDelegate(self)
    }

    private func setupHeaderStroke() {
        headerStroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        // distance between first section (the rest is covered by sections footers)
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(UserTableViewCell.self, forCellReuseIdentifier: "UserCell")
        tableView.register(ClearUserTableViewCell.self, forCellReuseIdentifier: "ClearUserCell")
        tableView.keyboardDismissMode = .onDrag
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
        let shadowVisible = tableView.contentOffset.y > 0
        if shadowVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                headerView.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                headerView.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            headerView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                                    y: headerView.bounds.maxY - 10,
                                                                    width: headerView.bounds.width,
                                                                    height: 10)).cgPath
        } else {
            headerView.layer.shadowOpacity = 0
        }
    }
}

// MARK: - filtering users

extension UserPickerCardViewController: SearchViewDelegate {
    func searchView(_: SearchView, textDidChange text: String) {
        filter(by: text)
    }

    /// filter `users` by given String and store results in `filteredUsers`
    func filter(by filterString: String) {
        let filterStringTrimmed = filterString.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let filterTerm = filterStringTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        let filterTerms = filterTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // user matches if the corresponding searchString matches
        filteredUsers = users.enumerated().compactMap { userIndex, user in
            // has to contain all of the search terms
            if filterTerms.allSatisfy({ searchStrings[userIndex].contains($0) }) {
                return user
            }
            return nil
        }
        tableView.reloadData()
    }
}

// MARK: - users table view delegate / data source

extension UserPickerCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        selectedUser != nil ? 2 : 1
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if selectedUser != nil, section == 0 {
            // first section with one row to clear the selected user
            return 1
        }
        return filteredUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if selectedUser != nil, indexPath.section == 0 {
            // first section with one row to clear the selected user
            return tableView.dequeueReusableCell(withIdentifier: "ClearUserCell", for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! UserTableViewCell
        let user = filteredUsers[indexPath.row]
        cell.setUser(user, selected: user == selectedUser)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamicColor(light: .Neutral_02, dark: .Neutral_09),
            borderColor: .dynamicColor(light: .Neutral_04, dark: .Neutral_07),
            selectedBackgroundColor: .systemGray4 // this is what selectedBackgroundView uses by default
        )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if selectedUser != nil, indexPath.section == 0 {
            // clear the selected user
            dismissCard()
            onUserPicked?(nil)
        } else {
            let user = filteredUsers[indexPath.row]
            dismissCard()
            onUserPicked?(user)
        }
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

    func scrollViewDidScroll(_: UIScrollView) {
        updateHeaderShadow()
    }
}
