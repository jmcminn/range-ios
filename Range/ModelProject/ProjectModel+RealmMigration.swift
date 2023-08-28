import Foundation
import OSLog
import RealmSwift

/// Defines the migration of old Realm schemas
extension ProjectModel {
    class func migrate(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        if oldSchemaVersion < 8 {
            // schema version 8 changes Upload.FileType.image to jpeg
            migrateToSchemaVersion8(migration)
        }
        if oldSchemaVersion < 10 {
            // schemaVersion 10 renames PDFCanvas -> Canvas and adds CanvasSource
            migrateToSchemaVersion10(migration)
        }

        // v12 introduces optional Upload.annotations (no Firestore sync), migration not needed
        // v13 introduces Upload.localStorageVersion (no Firestore sync), migration not needed
        // v14 introduces Participant.organizationIds, migration not needed (this field is empty for project model, only used for projectsModel)
        // v15 introduces Participant.participation(state), migration not needed
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
}
