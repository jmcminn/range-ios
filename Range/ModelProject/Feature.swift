import Foundation
import RealmSwift

// TODO: remove this class in a version deployed after RequiredMinimumVersion.iOS == "1.11.0"
// The reason is: migration to version 26 must run with Feature object in Realm as this is how
// Realm works (even though the migration actually removes the Feature, but there are some
// backlinks in Collaboration so it needs the Feature). And migration 26 is deployed in 1.11.0.
// So we can only remove the Feature after migration 26 is guaranteed to have run already.
/// Obsolete, but cannot be removed yet as because of how Realm works... (need to migrate first to remove it as it has back links)
class Feature: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// name
    @Persisted var name: String
    /// description (can't really use the description name for it as it's already used)
    @Persisted var featureDescription: String?
    /// collaborations for this feature, the order doesn't matter so it's a set
    @Persisted var collaborations: MutableSet<Collaboration>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }
}
