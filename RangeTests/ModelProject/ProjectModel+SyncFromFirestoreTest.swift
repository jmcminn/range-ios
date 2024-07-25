@testable import Range
import XCTest

final class ProjectModel_SyncFromFirestoreTest: ProjectModelTestCase {
    func testUpsertObjects() throws {
        try realm.write {
            realm.add(Geometry(placeholderId: "g1"))
            realm.add(Geometry(placeholderId: "g2"))
        }

        let geometryObjects = [
            ["id": "g1",
             "canvas": "canvas1",
             "annotationType": "photoMarker",
             "coordinates": "[-96.5, 32.5]"],
            ["id": "g3",
             "canvas": "canvas1",
             "annotationType": "photoMarker",
             "coordinates": "[-96.5, 32.5]"],
        ]
        try realm.write {
            model.upsertObjects(geometryObjects, as: FirestoreGeometry.self, inRealm: realm)
        }
        
        let geometries = realm.objects(Geometry.self)
        XCTAssertEqual(["g1", "g2", "g3"], geometries.map(\.id).sorted(), "the result should be the union of old and new objects")
    }
    
    func testUpsertObjects_replacingOldObjects() throws {
        try realm.write {
            realm.add(Geometry(placeholderId: "g1"))
            realm.add(Geometry(placeholderId: "g2"))
        }

        let geometryObjects = [
            ["id": "g1",
             "canvas": "canvas1",
             "annotationType": "photoMarker",
             "coordinates": "[-96.5, 32.5]"],
            ["id": "g3",
             "canvas": "canvas1",
             "annotationType": "photoMarker",
             "coordinates": "[-96.5, 32.5]"],
        ]
        try realm.write {
            model.upsertObjects(geometryObjects, as: FirestoreGeometry.self, inRealm: realm, replace: true)
        }
        
        let geometries = realm.objects(Geometry.self)
        XCTAssertEqual(["g1", "g3"], geometries.map(\.id).sorted(), "g2 should be removed")
    }

}
