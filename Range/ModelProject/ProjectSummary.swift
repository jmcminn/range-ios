import CoreLocation
import Foundation
import RealmSwift
import UIKit

/// Realm object for `project/summary`.
class ProjectSummary: Object, WithPlaceholder, WithId {
    /// Supported project types, all others are ignored by Range iOS app
    enum ProjectType: String, Codable, PersistableEnum {
        case architecture = "ARCHITECTURE_ID"
        case construction = "CONSTRUCTION_ID"
        case landscaping = "LANDSCAPING_ID"
        case retrofit = "RETROFIT_ID"
        case other = "OTHER_ID"
        init?(fromId: String) {
            if let type = ProjectType.allCases.first(where: { $0.rawValue == fromId }) {
                self = type
            } else { return nil }
        }
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Project name
    @Persisted var name: String
    /// parent organizationId
    @Persisted var organizationId: String
    /// Project description
    @Persisted var projectDescription: String?
    /// Project address
    @Persisted var address: String?
    /// Center geo location for the project
    @Persisted var center: CLLocationCoordinate2D
    /// project type
    @Persisted var projectType: ProjectType = .architecture
    /// project time zone
    // TODO: should be read from Firestore when it's implemented there
    // to be based on TZ Database name column from https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    var timeZone: TimeZone = .init(identifier: "America/Los_Angeles") ?? TimeZone.current
    /// array of canvas ids for sorting the canvases in UI
    @Persisted var canvasOrder: List<String>
    /// UI identifier for project
    @Persisted var identifier: String?
    /// whether project is archived
    @Persisted var isArchived: Bool = false
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false
    /// Number of tasks per given status. Only available on organization model (not tracked on project model level)
    @Persisted var statusTaskCounts: List<StatusTaskCount>

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        name: String,
        organizationId: String,
        center: CLLocationCoordinate2D,
        description: String?,
        address: String?,
        projectType: ProjectType,
        canvasOrder: [String] = [],
        identifier: String? = nil,
        isArchived: Bool = false,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.name = name
        self.organizationId = organizationId
        self.center = center
        projectDescription = description
        self.address = address
        self.projectType = projectType
        self.canvasOrder.removeAll()
        self.canvasOrder.append(objectsIn: canvasOrder)
        self.identifier = identifier
        self.isArchived = isArchived
        self.placeholder = placeholder
    }

    required convenience init(placeholderId: String) {
        self.init(
            id: placeholderId,
            name: "",
            organizationId: "",
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            description: nil,
            address: nil,
            projectType: .other,
            placeholder: true
        )
    }
}

class StatusTaskCount: EmbeddedObject {
    @Persisted var id: String
    @Persisted var name: String
    @Persisted var hexColor: String
    @Persisted var taskCount: Int

    lazy var color = UIColor(hexString: hexColor) ?? .black

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    init(id: String, name: String, hexColor: String, taskCount: Int) {
        super.init()
        self.id = id
        self.name = name
        self.hexColor = hexColor
        self.taskCount = taskCount
    }
}
