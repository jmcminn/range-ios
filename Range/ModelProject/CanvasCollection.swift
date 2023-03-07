import Foundation
import RealmSwift

/// Realm object for `project/<id>/canvasCollections/<id>`.
class CanvasCollection: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String

    /// canvases for this collection, the order doesn't matter so it's a set
    @Persisted var canvases: MutableSet<Canvas>
    /// The name of canvas collection
    @Persisted var name: String
    /// The storage version of the PDF file
    @Persisted var storageVersion: String?
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, storageVersion: String? = nil, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.storageVersion = storageVersion
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, name: "", storageVersion: nil, placeholder: true)
    }
}
