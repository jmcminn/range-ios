import Foundation
import OSLog
import RealmSwift

/// Defines the migration of old Realm schemas
extension UserModel {
    class func migrate(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        // v3 introduces Participant.organizationIds and Organization, migration not needed (this field is empty for project model, only used for userModel)
        // v4 introduces Participant.participation(state)

        if oldSchemaVersion < 5 {
            // v5 replaces Participant with User
            migrateToSchemaVersion5(migration)
        }
    }

    /// v5 replaces Participant with User
    private class func migrateToSchemaVersion5(_ migration: Migration) {
        migration.deleteData(forType: "Participant")
    }
}
