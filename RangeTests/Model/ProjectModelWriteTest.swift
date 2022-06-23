
import CoreLocation
import Kingfisher
@testable import Range
import RealmSwift
import Turf
import XCTest

class ProjectModelWriteTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!
    var canvas: PDFCanvas!
    let coordinates = CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)

    @MainActor
    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(userId: "user1", projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
        canvas = PDFCanvas(id: "canvas1", url: "url1", pageNumber: 0, userDefinedScale: 1)
        try realm.write {
            realm.add(canvas)
        }
    }

    /// throws when canvas not found
    @MainActor
    func testCreatePhotoMarker_canvasNotFound() async throws {
        let canvas = PDFCanvas(id: "canvas2", url: "url2", pageNumber: 0, userDefinedScale: 1)

        do {
            _ = try await model.createPhotoMarker(canvas: canvas, coordinates: coordinates)
            XCTFail("This call should throw an error.")
        } catch let error as ModelError {
            XCTAssertEqual(error, ModelError.canvasNotFound)
        }
    }

    @MainActor
    func testCreatePhotoMarker_successful() async throws {
        let collaboration = try await model.createPhotoMarker(canvas: canvas, coordinates: coordinates)
        let geometry = try XCTUnwrap(collaboration.feature.first?.geometry.first)
        XCTAssertEqual(geometry.canvas.first, canvas)
        XCTAssertEqual(geometry.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))))
    }

    /// throws when no geometry with given id
    @MainActor
    func testGetOrAddCollaboration_geometryNotFound() async throws {
        do {
            _ = try await model.getOrAddCollaboration(forGeometryId: "geometry1")
            XCTFail("This call should throw an error.")
        } catch let error as ModelError {
            XCTAssertEqual(error, ModelError.geometryNotFound)
        }
    }

    /// adds feature and collaboration if feature missing
    @MainActor
    func testGetOrAddCollaboration_noFeature() async throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(coordinates))
        )
        try realm.write {
            realm.add(geometry)
        }

        let collaboration = try await model.getOrAddCollaboration(forGeometryId: "geometry1")
        XCTAssertEqual(collaboration.feature.first?.geometry.first, geometry)
    }

    /// adds collaboration if it's missing
    @MainActor
    func testGetOrAddCollaboration_noCollaboration() async throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(coordinates))
        )
        let feature = Feature(id: "feature1", name: "")
        try realm.write {
            realm.add([geometry, feature])
            geometry.features.insert(feature)
        }

        let collaboration = try await model.getOrAddCollaboration(forGeometryId: "geometry1")
        XCTAssertEqual(collaboration.feature.first?.geometry.first, geometry)
        XCTAssertEqual(collaboration.feature.first, feature)
    }

    /// all object exist, just return collaboration
    @MainActor
    func testGetOrAddCollaboration_get() async throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(coordinates))
        )
        let feature = Feature(id: "feature1", name: "")
        let collaboration = Collaboration(id: "collaboration1", name: "", description: "")
        try realm.write {
            realm.add([geometry, feature, collaboration])
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }

        let resultCollaboration = try await model.getOrAddCollaboration(forGeometryId: "geometry1")
        XCTAssertEqual(resultCollaboration.feature.first?.geometry.first, geometry)
        XCTAssertEqual(resultCollaboration.feature.first, feature)
        XCTAssertEqual(resultCollaboration, collaboration)
    }

    /// throws when current user not found
    @MainActor
    func testAddUpload_currentUserNotFound() async throws {
        let collaboration = Collaboration(id: "collaboration1", name: "", description: "")
        do {
            _ = try await model.addUpload(Data(), tags: [], description: "", toCollaboration: collaboration)
            XCTFail("This call should throw an error.")
        } catch let error as ModelError {
            XCTAssertEqual(error, ModelError.currentUserNotFound)
        }
    }

    /// throws when collaboration not found
    @MainActor
    func testAddUpload_collaborationNotFound() async throws {
        let user = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add(user)
        }
        let collaboration = Collaboration(id: "collaboration1", name: "", description: "")
        do {
            _ = try await model.addUpload(Data(), tags: [], description: "", toCollaboration: collaboration)
            XCTFail("This call should throw an error.")
        } catch let error as ModelError {
            XCTAssertEqual(error, ModelError.collaborationNotFound)
        }
    }

    @MainActor
    func testAddUpload_successful() async throws {
        let user = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        let tag = Tag(id: "tag1", name: "tag 1")
        let collaboration = Collaboration(id: "collaboration1", name: "", description: "")
        try realm.write {
            realm.add([user, tag, collaboration])
        }
        let upload = try await model.addUpload(Data(),
                                               tags: [
                                                   TagViewModel(id: "tag1", name: "tag 1"),
                                                   TagViewModel(id: "tag2", name: "new tag"),
                                               ],
                                               description: "upload description",
                                               toCollaboration: collaboration)
        XCTAssertEqual(collaboration.uploads.first, upload)
        XCTAssertEqual(upload.author, user)
        XCTAssertEqual(upload.tags.count, 2)
        XCTAssertEqual(upload.tags[0].id, "tag1")
        XCTAssertEqual(upload.tags[1].id, "tag2")
        XCTAssertEqual(realm.objects(Tag.self).count, 2)
        XCTAssertEqual(upload.uploadDescription, "upload description")
        XCTAssertTrue(upload.url.isFileURL)
        XCTAssertTrue(model.localPhotosCache.isCached(forKey: upload.id))
        XCTAssertEqual(
            try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1")).uploads.first,
            upload
        )
        XCTAssertEqual(
            try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1")).uploads.first,
            upload
        )
    }
}
