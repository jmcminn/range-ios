import RealmSwift
import UIKit

/// Realm object for `project/details/uploads/<id>`.
class Upload: Object, WithPlaceholder {
    /// Supported file types, all others are ignored by Range iOS app
    enum FileType: String, PersistableEnum {
        case image
        case pdf
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // the author, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    /// Backlink to the Collaboration. This is automatically updated whenever this upload is added to or removed from the parent
    @Persisted(originProperty: "uploads") var collaboration: LinkingObjects<Collaboration>
    // timestamp (since 1970)
    @Persisted var timestamp: TimeInterval
    // url
    @Persisted var url: URL?
    // name
    @Persisted var name: String?
    // description
    @Persisted var uploadDescription: String?
    /// tags attached to the upload, ordered
    @Persisted var tags: List<Tag>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false
    /// Versions of a photo has the same correlationId (the id of the first version)
    @Persisted var correlationId: String
    /// Image aspect ratio. Stored locally when the image is downloaded from the Storage
    /// Not synchronized with backend
    @Persisted var imageHeightToWidth: Double?
    /// File type
    @Persisted var fileType: FileType

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        timestamp: TimeInterval,
        url: URL?,
        name: String?,
        description: String?,
        correlationId: String,
        fileType: FileType,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.name = name
        self.correlationId = correlationId
        self.fileType = fileType
        uploadDescription = description
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            timestamp: 0,
            url: nil,
            name: "",
            description: nil,
            correlationId: id,
            fileType: .image,
            placeholder: true
        )
    }
}
