import RealmSwift
import UIKit

/// Realm object for `project/details/participants/<id>`.
class Participant: Object, WithPlaceholder, WithId {
    // The .removed state is needed as we don't want to remove the user from DB as it might be attached to
    // many other objects (comments, uploads, collaborations) and the Participant might be only temporarily
    // removed when switching from active to suspended and vice-versa.
    // We want to preserve the link between other objects and this participant no matter what is the order
    // of adding/removing participants vs suspendedParticipants.
    // The end result is that there's one Participant in the local db synced from either FirestoreParticipant
    // or FirestoreSuspendedParticipant and when suspending/unsuspending the user the link between
    // this Participant and other model objects is preserved
    enum ParticipationState: String, Codable, PersistableEnum {
        case active // user is an active participant of project
        case suspended // user is a suspended participant of the project (the name will be striked through
        // and user cannot be assigned to tasks, etc)
        case removed // user is removed from project (the displayed name will be empty, cannot be listed in user selection)
    }

    enum OrganizationRole: String, Codable, PersistableEnum {
        case Admin
        case Collaborator
        case Guest
        case Unknown // only valid for suspended participants
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// user first name (@objc added so it can be used in SortDescriptor)
    @objc @Persisted var firstName: String
    /// user last name
    @objc @Persisted var lastName: String
    /// avatar url
    @Persisted var avatarUrl: URL?
    /// email
    @Persisted var email: String
    /// Whether this participant is currently suspended in the Project
    @Persisted var participation: ParticipationState = .active
    /// Users role in the organization
    @Persisted var organizationRole: OrganizationRole = .Admin
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    lazy var avatarImage: UIImage? = avatarUrl
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { UIImage(data: $0) }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        firstName: String,
        lastName: String,
        avatarUrl: URL?,
        email: String,
        participation: ParticipationState = .active,
        organizationRole: OrganizationRole,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.email = email
        self.participation = participation
        self.organizationRole = organizationRole
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            firstName: "",
            lastName: "",
            avatarUrl: nil,
            email: "",
            participation: .active,
            organizationRole: .Collaborator,
            placeholder: true
        )
    }
}

/// UI properties
extension Participant {
    /// The value to display in the UI
    var displayName: String {
        guard participation != .removed else { return "" }
        var components: [String] = []
        if !firstName.isEmpty { components.append(firstName) }
        if !lastName.isEmpty { components.append(lastName) }
        return components.joined(separator: " ")
    }

    var initials: String {
        guard participation != .removed else { return "" }
        if let firstNameLetter = firstName.first { return String(firstNameLetter) }
        if let lastNameLetter = lastName.first { return String(lastNameLetter) }
        return ""
    }

    /// Returns NSUnderlineStyle.rawValue - striked through when suspended or removed and non striked through when active
    var strikethroughStyle: Int {
        participation == .active ? NSUnderlineStyle([]).rawValue : NSUnderlineStyle.single.rawValue
    }

    var tasksCreatedByUser: Results<Collaboration> {
        guard let realm = realm else { fatalError("user is unmanaged") }
        return realm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.author == self && c.status != nil
            }
    }
}
