import Foundation
import SnapKit
import UIKit

/// Card view controller presenting a list of users to choose from.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class UserPickerCardViewController: SheetCardViewController {
    /// users to select
    private let viewModel: UsersViewModel

    // background view for searchView that has the headerStroke at the bottom, added so it can
    // have a shadow when scrolling the users
    private let headerView = UIView()
    private let searchView = SearchView()
    // only when viewModel is multiselect
    private let selectedUsersView: SelectedUsersView?
    private let headerStroke = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    private static var headerHeight = 56
    private static var headerHeightWithSelectedUsers = 100
    private var headerHeightConstraint: Constraint?

    /// Show a special row (in the 1st section) that allows for selecting the "no user option" (to remove the user in single selection or to selected the unassigned option in multiselect)
    var showNoUserOption: Bool = false

    init(title: String, viewModel: UsersViewModel) {
        self.viewModel = viewModel
        selectedUsersView = viewModel.multiselect
            ? SelectedUsersView(viewModel: viewModel, showEditUserCell: false)
            : nil

        super.init(icon: UIImage(systemName: "person"), title: title)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderVew()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            if selectedUsersView != nil, !viewModel.selectedUsers.isEmpty {
                self.headerHeightConstraint = make.height
                    .equalTo(UserPickerCardViewController.headerHeightWithSelectedUsers).constraint
            } else {
                self.headerHeightConstraint = make.height.equalTo(UserPickerCardViewController.headerHeight).constraint
            }
        }

        setupSearchView()
        headerView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
        }

        if let selectedUsersView = selectedUsersView {
            selectedUsersView.isHidden = viewModel.selectedUsers.isEmpty
            headerView.addSubview(selectedUsersView)
            selectedUsersView.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.bottom.equalToSuperview().offset(-12)
            }
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

        viewModel.addDelegate(self)
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
        searchView.placeholderText = viewModel.multiselect ? "Search for users..." : "Search for an assignee..."
        searchView.addDelegate(self)
    }

    private func setupHeaderStroke() {
        headerStroke.backgroundColor = .dynamic(.Neutral_07)
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
        tableView.register(
            UserTableViewCell.self,
            forCellReuseIdentifier: UserTableViewCell.Variant.identifier(forMultiselect: viewModel.multiselect)
        )
        tableView.register(
            ClearUserTableViewCell.self,
            forCellReuseIdentifier: ClearUserTableViewCell.Variant.identifier(forMultiselect: viewModel.multiselect)
        )
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

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        updateHeaderShadow()
    }
}

// MARK: - view model delegate

extension UserPickerCardViewController: UsersViewModelDelegate {
    func usersViewModel(
        _ viewModel: UsersViewModel,
        user: UserViewModel,
        selected: Bool,
        indexInSelectedUsers _: Int
    ) {
        guard viewModel.multiselect else { return }

        // 1. for multiselect we need to reload rows that are affected by selection
        let indexPath: IndexPath
        if user.id == UserViewModel.unassignedUserId {
            indexPath = IndexPath(item: 0, section: 0)
        } else {
            indexPath = IndexPath(item: viewModel.filteredUsers.firstIndex(of: user) ?? 0, section: 1)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)

        // 2. show/hide the selected users depending on the list being not empty
        updateSelectedUsersVisibility(userSelected: selected)
    }

    func updateSelectedUsersVisibility(userSelected selected: Bool) {
        guard let selectedUsersView = selectedUsersView else { return }
        // only handle first selected user (show users) or last unselected (hide users)
        guard (selected == true && viewModel.selectedUsers.count == 1)
            || (selected == false && viewModel.selectedUsers.count == 0) else { return }

        selectedUsersView.visibleStateWillTransition()
        if selected {
            // showing the users
            headerHeightConstraint?.update(offset: UserPickerCardViewController.headerHeightWithSelectedUsers)
            // first animate the header height
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            } completion: { _ in
                // when enough room show the selected users
                selectedUsersView.setVisible(selected, animated: true)
            }
        } else {
            // first hide the users
            selectedUsersView.setVisible(false, animated: true) {
                // then animate the header to its new height
                self.headerHeightConstraint?.update(offset: UserPickerCardViewController.headerHeight)
                UIView.animate(withDuration: 0.1) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
}

// MARK: - filtering users

extension UserPickerCardViewController: SearchViewDelegate {
    func searchView(_: SearchView, textDidChange text: String) {
        viewModel.filter(by: text)
        tableView.reloadData()
    }
}

// MARK: - users table view delegate / data source

extension UserPickerCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        showNoUserOption ? 2 : 1
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showNoUserOption, section == 0 {
            // first section with one row to clear the selected user
            return 1
        }
        return viewModel.filteredUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if showNoUserOption, indexPath.section == 0 {
            // first section with one row to clear the selected user
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ClearUserTableViewCell.Variant.identifier(forMultiselect: viewModel.multiselect),
                for: indexPath
            ) as! ClearUserTableViewCell
            if viewModel.multiselect {
                cell.setUser(viewModel.unassignedUser)
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UserTableViewCell.Variant.identifier(forMultiselect: viewModel.multiselect),
            for: indexPath
        ) as! UserTableViewCell
        let user = viewModel.filteredUsers[indexPath.row]
        cell.setUser(user)
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
        if viewModel.multiselect {
            let user = showNoUserOption && indexPath.section == 0
                ? viewModel.unassignedUser
                : viewModel.filteredUsers[indexPath.row]
            viewModel.set(userWithId: user.id, selected: !user.selected)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        } else {
            if showNoUserOption, indexPath.section == 0 {
                // clear the selected user
                viewModel.clearSelection()
                dismissCard()
                onClose?()
            } else {
                let user = viewModel.filteredUsers[indexPath.row]
                if !user.selected {
                    viewModel.set(userWithId: user.id, selected: true)
                }
                dismissCard()
                onClose?()
            }
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
}
