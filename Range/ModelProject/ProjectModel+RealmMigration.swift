import Foundation
import OSLog
import RealmSwift

/// Defines the migration of old Realm schemas
extension ProjectModel {
    class func migrate(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        // schema version 8 changes Upload.FileType.image to jpeg
        if oldSchemaVersion < 8 { migrateToSchemaVersion8(migration) }

        // schemaVersion 10 renames PDFCanvas -> Canvas and adds CanvasSource
        if oldSchemaVersion < 10 { migrateToSchemaVersion10(migration) }

        // v12 introduces optional Upload.annotations (no Firestore sync), migration not needed
        // v13 introduces Upload.localStorageVersion (no Firestore sync), migration not needed
        // v14 introduces Participant.organizationIds, migration not needed (this field is empty for project model, only used for userModel)
        // v15 introduces Participant.participation(state), migration not needed
        // v16 removes Participant.organizationIds,projectIds,fcmTokens, they are now handled by the User object
        // v17 adds Participant.organizationRole
        // v18 adds ProjectSummary.canvasOrder
        // v19 adds ProjectSummary.projectType
        // v20 introduces ProjectSummary.organizationId
        // v21 introduces ProjectSummary.identifier and Collaboration.identifier
        // v22 introduces ProjectSummary.statusTaskCounts
        // v23 introduces Collaboration.followers
        // v24 introduces ProjectMetadata

        // v25 renames timestamp to createdAt and introduces lastUpdatedAt = timestamp
        if oldSchemaVersion < 25 { migrateToSchemaVersion25(migration) }

        // v26 removes Feature and links Geometry directly to Collaboration
        if oldSchemaVersion < 26 { migrateToSchemaVersion26(migration) }
    }

    /// schemaVersion 10 renames PDFCanvas -> Canvas and adds CanvasSource
    /// Renaming objects is not a supported migration so we need to create new Canvas objects,
    /// link them with canvas collection and geometries of old PDFCanvas objects and remove the old ones
    /// When migrating we have:
    /// Old realm: CanvasCollection -> PDFCanvas -> Geometry
    /// New realm: CanvasCollection ->  Canvas   -> Geometry
    ///                                   └---> CanvasSource
    ///
    /// We want to reuse CanvasCollections and Geometries and only create new Canvases and relink on both sides
    private class func migrateToSchemaVersion10(_ migration: Migration) {
        // 1. store geometries from new version so they can be reassigned to newly created Canvases
        // map of id => new geometry
        var newGeometries = [String: MigrationObject]()
        migration.enumerateObjects(ofType: "Geometry") { _, newObject in
            guard let newObject = newObject, let id = newObject["id"] as? String else { return }
            newGeometries[id] = newObject
        }

        // 2. go over canvas collections and add to them new Canvases based on their old PDFCanvases
        migration.enumerateObjects(ofType: "CanvasCollection") { oldCollection, newCollection in
            guard let oldCollection = oldCollection, let newCollection = newCollection else { return }
            guard let oldCanvases = oldCollection["canvases"] as? MutableSet<MigrationObject> else { return }
            for oldCanvas in oldCanvases {
                let newCanvas: MigrationObject = migration.create("Canvas")
                let canvasId: String = oldCanvas["id"] as! String

                // 2a. copy data
                newCanvas["id"] = canvasId
                newCanvas["name"] = oldCanvas["name"]

                // 2b. migrate canvas data to canvas source
                let pdfCanvasSource = migration.create("CanvasSource")
                pdfCanvasSource["id"] = canvasId + "_source"
                pdfCanvasSource["name"] = ""
                var canvasSourceData: [String: Any] = [
                    "type": "pdf",
                    "userDefinedScale": oldCanvas["userDefinedScale"]!,
                    "pageNumber": oldCanvas["pageNumber"]!,
                ]
                if let sheetNumber = oldCanvas["sheetNumber"] {
                    canvasSourceData["sheetNumber"] = sheetNumber
                }
                do {
                    pdfCanvasSource["data"] = try String(data: JSONSerialization
                        .data(withJSONObject: canvasSourceData, options: []), encoding: .utf8)
                    if let newSources = newCanvas["canvasSources"] as? MutableSet<MigrationObject> {
                        newSources.insert(pdfCanvasSource)
                    }
                } catch {
                    // fail to migrate
                    Logger.model.error("Failed to migrate canvas to canvasSource: \(error.localizedDescription)")
                }

                // 2c. add new geometries to new canvas...
                if let oldCanvasGeometries = oldCanvas["geometries"] as? MutableSet<MigrationObject>,
                   let newCanvasGeometries = newCanvas["geometries"] as? MutableSet<MigrationObject>
                {
                    for oldCanvasGeometry in oldCanvasGeometries {
                        if let id = oldCanvasGeometry["id"] as? String, let newCanvasGeometry = newGeometries[id] {
                            newCanvasGeometries.insert(newCanvasGeometry)
                        }
                    }
                }

                // 2d. insert new canvas to canvas collection
                (newCollection["canvases"] as? MutableSet<MigrationObject>)?.insert(newCanvas)
            }
        }

        // 3. remove old PDFCanvases
        migration.deleteData(forType: "PDFCanvas")
    }

    /// schema version 8 changes Upload.FileType.image to jpeg
    private class func migrateToSchemaVersion8(_ migration: Migration) {
        migration.enumerateObjects(ofType: "Upload") { oldObject, newObject in
            if let fileType = oldObject!["fileType"] as? String, fileType == "image" {
                newObject!["fileType"] = "jpeg"
            }
        }
    }

    /// v25 renames timestamp to createdAt and introduces lastUpdatedAt = timestamp
    private class func migrateToSchemaVersion25(_ migration: Migration) {
        let addLastUpdatedAt: MigrationObjectEnumerateBlock = { oldObject, newObject in
            if let timestamp = oldObject!["timestamp"] as? Date {
                newObject!["lastUpdatedAt"] = timestamp
            }
        }
        migration.enumerateObjects(ofType: "Collaboration", addLastUpdatedAt)
        migration.enumerateObjects(ofType: "Comment", addLastUpdatedAt)
        migration.enumerateObjects(ofType: "Upload", addLastUpdatedAt)

        migration.renameProperty(onType: "Collaboration", from: "timestamp", to: "createdAt")
        migration.renameProperty(onType: "Comment", from: "timestamp", to: "createdAt")
        migration.renameProperty(onType: "Update", from: "timestamp", to: "createdAt")
        migration.renameProperty(onType: "Upload", from: "timestamp", to: "createdAt")
    }

    /// Adds a direct link between Geometry and Collaboration and removes Feature
    private class func migrateToSchemaVersion26(_ migration: Migration) {
        // 1. store collaborations from new version so they can be assigned to Geometry
        // map of id => new collaboration
        var newCollaborations = [String: MigrationObject]()
        migration.enumerateObjects(ofType: "Collaboration") { _, newObject in
            guard let newObject, let id = newObject["id"] as? String else { return }
            newCollaborations[id] = newObject
        }
        migration.enumerateObjects(ofType: "Geometry") { oldGeometry, newGeometry in
            guard let oldGeometry, let newGeometry else { return }

            // this code is (properly) assuming that there at most 1 feature per geometry and
            // 1 collaboration per feature
            guard let oldFeature = (oldGeometry["features"] as? MutableSet<MigrationObject>)?.first else { return }
            if let oldCollaboration = (oldFeature["collaborations"] as? MutableSet<MigrationObject>)?.first,
               let collaborationId = oldCollaboration["id"] as? String,
               let newCollaboration = newCollaborations[collaborationId]
            {
                (newGeometry["collaborations"] as? MutableSet<MigrationObject>)?.insert(newCollaboration)
            }
        }
        migration.deleteData(forType: "Feature")
    }
}
