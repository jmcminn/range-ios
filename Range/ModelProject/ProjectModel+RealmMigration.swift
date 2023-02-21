import Foundation
import RealmSwift

/// Defines the migration of old Realm schemas
extension ProjectModel {
    class func migrate(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        // schema version 8 changes Upload.FileType.image to jpeg
        if oldSchemaVersion < 8 {
            migration.enumerateObjects(ofType: Upload.className()) { oldObject, newObject in
                if let fileType = oldObject!["fileType"] as? String, fileType == "image" {
                    newObject!["fileType"] = "jpeg"
                }
            }
        }
    }
}
