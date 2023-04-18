import Algorithms
import Foundation
import RealmSwift

/// View model for list of users and support for selecting/deselecting
class UsersViewModel: NSObject {
    /// whether it's a multi or single select model
    let multiselect: Bool
    /// all users whether selected or not
    private(set) var allUsers: [UserViewModel]
    /// For fast lookup by id
    private var allUsersIndex: [String: UserViewModel]
    /// a subset of all users storing selected users in order they were being selected
    private(set) var selectedUsers: [UserViewModel] = []
    /// filter to be used on `allUsers` to derive `filteredUsers`
    private(set) var filterString: String = ""
    /// a subset of all users matching the current filter in the order as in `allUsers`
    private(set) var filteredUsers: [UserViewModel] = []

    /// used for sorting the users by name
    private let nameSort = SortDescriptor(\UserViewModel.name, comparator: .localizedStandard)

    /// Allows for multiple delegates
    private var delegates = NSHashTable<UsersViewModelDelegate>.weakObjects()

    /// Special user with id = UserViewModel.unassignedUserId for filtering unassigned tasks
    let unassignedUser: UserViewModel

    init(model: ProjectModel, multiselect: Bool) {
        self.multiselect = multiselect
        allUsers = model.mainRealm.objects(Participant.self)
            .where { $0.placeholder == false }
            .map { UserViewModel(fromParticipant: $0) }
            .sorted(using: nameSort)

        allUsersIndex = Dictionary(uniqueKeysWithValues: zip(allUsers.map(\.id), allUsers))
        unassignedUser = UserViewModel.unassignedUser()
        allUsersIndex[unassignedUser.id] = unassignedUser

        super.init()

        filteredUsers = allUsers
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: UsersViewModelDelegate) {
        delegates.add(delegate)
    }

    /// Mark user with given id as selected/deselected and notify delegates
    /// If user with given id is not present it's ignored
    func set(userWithId userId: String, selected: Bool) {
        // find user with matching id in this view model tags
        guard let user = allUsersIndex[userId] else { return }
        guard user.selected != selected else { return }

        // store ids to unselect at the end (after selection)
        // the unselection is done after selection so switching selection doesn't produce
        // a temporary empty selection (which doesn't work nicely with the animations
        // based on the callbacks from model).
        // TODO: Ideally all the selections/unselections  would be propagated in 1 delegate call (kind of transactional)
        let userIdsToUnselect: [String]?
        if selected {
            if multiselect {
                // for multiselect the unassignedUser selection is exclusive with the rest of users
                if userId == UserViewModel.unassignedUserId {
                    // selecting unassigned user clears the selection
                    userIdsToUnselect = selectedUsers.map(\.id)
                } else {
                    // selecting a user clears the unassigned user selection
                    userIdsToUnselect = [UserViewModel.unassignedUserId]
                }
            } else {
                // for single selection we unselect the previously selected
                userIdsToUnselect = selectedUsers.map(\.id)
            }
        } else {
            userIdsToUnselect = nil
        }

        user.selected = selected
        if user.selected {
            // insert as last user in selected list
            selectedUsers.append(user)
            let insertIndex = selectedUsers.count - 1
            delegates.allObjects
                .forEach { $0.usersViewModel?(self, user: user, selected: true, indexInSelectedUsers: insertIndex) }
        } else {
            if let deleteIndex = selectedUsers.firstIndex(of: user) {
                selectedUsers.remove(at: deleteIndex)
                delegates.allObjects
                    .forEach { $0.usersViewModel?(self, user: user, selected: false, indexInSelectedUsers: deleteIndex)
                    }
            }
        }

        if let userIdsToUnselect = userIdsToUnselect {
            userIdsToUnselect.forEach { self.set(userWithId: $0, selected: false) }
        }
    }

    /// Unselect all selected users
    func clearSelection() {
        let selectedIds = selectedUsers.map(\.id)
        selectedIds.forEach { self.set(userWithId: $0, selected: false) }
    }

    /// filter `allUsers` by given String and store results in `filteredUsers`
    func filter(by filterString: String) {
        self.filterString = filterString
        let filterStringTrimmed = filterString.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let filterTerm = filterStringTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        let filterTerms = filterTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // user matches if it contains all the filterTerms
        filteredUsers = allUsers.filter { user in
            // has to contain all of the search terms
            filterTerms.allSatisfy { user.searchName.contains($0) }
        }
        delegates.allObjects.forEach { $0.usersViewModelFiltered?(self) }
    }
}

/// Delegate for `UsersViewModel`
///
/// see `SearchViewDelegate` for why it's @objc protocol
@objc protocol UsersViewModelDelegate: AnyObject {
    /// notifies that the given user was selected/deselected
    /// - Parameters:
    ///     - viewModel
    ///     - user selected user
    ///     - selected: selected or deselected
    ///     - indexInSelectedUsers: it's new index in the `selectedUsers`
    @objc optional func usersViewModel(
        _ viewModel: UsersViewModel,
        user: UserViewModel,
        selected: Bool,
        indexInSelectedUsers: Int
    )

    /// notifies that a filter was applied (or removed) from the viewModel.
    @objc optional func usersViewModelFiltered(_ viewModel: UsersViewModel)
}

/// View model for user with selection support
class UserViewModel: NSObject, Codable {
    /// A special id for user that is used for filtering unassigned tasks
    static let unassignedUserId = "unassigned"
    let id: String
    @objc let name: String
    @objc let email: String
    /// for searching we store a version of string that is diacriticInsensitive and caseInsensitive
    let searchName: String
    @objc fileprivate(set) dynamic var selected: Bool = false

    /// Initializer for existing users
    /// - Parameters:
    ///   - id: id
    ///   - name: name of the user
    ///   - usageCount: usage count
    ///   - newTag: whether this is a new tag to be created in the db
    init(
        id: String,
        name: String,
        email: String
    ) {
        self.id = id
        self.name = name
        self.email = email
        searchName = "\(name) \(email)".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Convenience initializer from the model Participant
    convenience init(fromParticipant participant: Participant) {
        self.init(id: participant.id, name: participant.displayName, email: participant.email)
    }

    static func unassignedUser() -> UserViewModel {
        UserViewModel(id: unassignedUserId, name: String(localized: "Unassigned Tasks"), email: "")
    }

    /// equatable to check for id only
    static func == (lhs: UserViewModel, rhs: UserViewModel) -> Bool {
        lhs.id == rhs.id
    }

    override var description: String {
        "'\(name)'[\(id.prefix(8))]"
    }
}
