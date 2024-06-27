import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `UpdateGeometryArchivedCommand` in local Realm db
final class UpdateGeometryArchivedCommandRealmTest: ProjectModelTestCase {
    func testApply_noGeometry() throws {
        let command = UpdateGeometryArchivedCommand(collaborationId: "collaboration1", archivedTimestamp: nil)
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.geometryNotFound)
        }
    }

    func testApply_archive_successful() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let feature = Feature(placeholderId: "feature1")
        let collaboration = Collaboration(placeholderId: "collaboration1")
        try realm.write {
            realm.add([geometry, feature, collaboration])
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
        let archivedTimestamp = Date()
        let command = UpdateGeometryArchivedCommand(collaborationId: "collaboration1", archivedTimestamp: archivedTimestamp)
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertEqual(geometry.archivedTimestamp, archivedTimestamp)
    }

    func testApply_unarchive_successful() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))),
            archivedTimestamp: Date()
        )
        let feature = Feature(placeholderId: "feature1")
        let collaboration = Collaboration(placeholderId: "collaboration1")
        try realm.write {
            realm.add([geometry, feature, collaboration])
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
        let command = UpdateGeometryArchivedCommand(collaborationId: "collaboration1", archivedTimestamp: nil)
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertNil(geometry.archivedTimestamp)
    }
}

/// Tests getting the parameters for Firebase function call
final class UpdateGeometryArchivedCommandFirebaseFunctionTest: XCTestCase {
    func test_archive() throws {
        let archivedTimestamp = Date()
        let command = UpdateGeometryArchivedCommand(collaborationId: "collaboration1", archivedTimestamp: archivedTimestamp)
        XCTAssertEqual(command.functionName, "updateCollaboration")
        
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "archivedTimestamp": Int(archivedTimestamp.timeIntervalSince1970 * 1000),
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
    
    func test_unarchive() throws {
        let command = UpdateGeometryArchivedCommand(collaborationId: "collaboration1", archivedTimestamp: nil)
        XCTAssertEqual(command.functionName, "updateCollaboration")
        
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "archivedTimestamp": nil
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
