import RealmSwift
import UIKit
import UniformTypeIdentifiers

/// Realm object for `project/details/uploads/<id>`.
class Upload: Object, WithPlaceholder {
    /// Supported file types, all others are ignored by Range iOS app
    enum FileType: String, Codable, PersistableEnum {
        case jpeg, png, pdf, docx, xlsx

        init?(fromExtension: String) {
            if let type = FileType.allCases.first(where: { $0.rawValue == fromExtension }) {
                self = type
            } else { return nil }
        }

        var mimeType: String {
            UTType(filenameExtension: rawValue)?.preferredMIMEType ?? "application/octet-stream"
        }

        var isImage: Bool { self == .jpeg || self == .png }
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // the author, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    /// Backlink to the Collaboration. This is automatically updated whenever this upload is added to or removed from the parent
    @Persisted(originProperty: "uploads") var collaboration: LinkingObjects<Collaboration>
    // timestamp (@objc to use it in SortDescriptor)
    @objc @Persisted var timestamp: Date
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
    /// Image aspect ratio. Optional as it's only provided for images
    @Persisted var imageHeightToWidth: Double?
    /// File type
    @Persisted var fileType: FileType
    /// Size of file in bytes, optional until data migrated
    @Persisted var fileSize: Int64?
    /// The storage versions (map of type, for example, "main", "thumbnail0" to version string)
    @Persisted var storageVersion: Map<String, String>
    /// comments, the order doesn't matter so it's a set (the order is controlled by the comment timestamp when displaying in the UI)
    @Persisted var comments: MutableSet<Comment>

    /// Derived from fileType
    var isImage: Bool { fileType.isImage }

    /// Full file name with extension, derived from name and fileType
    var fileName: String {
        let ext = fileType.rawValue
        if let name = name, !name.isEmpty {
            return "\(name).\(ext)"
        } else {
            return "\(id).\(ext)"
        }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        timestamp: Date,
        name: String?,
        description: String?,
        correlationId: String,
        fileType: FileType,
        imageHeightToWidth: Double?,
        fileSize: Int64?,
        storageVersion: [String: String]? = nil,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.name = name
        uploadDescription = description
        self.correlationId = correlationId
        self.fileType = fileType
        self.imageHeightToWidth = imageHeightToWidth
        self.fileSize = fileSize
        if let storageVersion = storageVersion {
            // merge overwriting with new values
            self.storageVersion.merge(storageVersion) { _, new in new }
        }
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            timestamp: Date(),
            name: "",
            description: nil,
            correlationId: id,
            fileType: .jpeg,
            imageHeightToWidth: nil,
            fileSize: nil,
            storageVersion: nil,
            placeholder: true
        )
    }

    // MARK: - upsert/command helper functions

    /// remove the upload from the tags it was attached to and is not anymore
    func cleanupOldTags(newTagIds: [String]) {
        // for fast lookup
        let tagIdsSet = Set(newTagIds)
        for tag in tags {
            if !tagIdsSet.contains(tag.id) {
                // updated tags don't contain this tag, remove the upload from it
                tag.uploads.remove(self)
            }
        }
    }

    /// Add given tags to upload and also link the Upload in Tags
    func addNewTags(newTagIds: [String], realm: Realm) {
        // for fast lookup
        let currentTagIdsSet = Set(tags.map(\.id))

        let newTags = newTagIds.uniqued()
            .filter { !currentTagIdsSet.contains($0) }
            .compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        tags.append(objectsIn: newTags)
        newTags.forEach { $0.uploads.insert(self) }
    }
}
