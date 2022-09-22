
import CoreLocation
import Kingfisher
@testable import Range
import RealmSwift
import Turf
import XCTest

class ProjectModelCommandsTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!
    var canvas: PDFCanvas!
    let coordinates = CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)

    @MainActor
    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(projectId: ""),
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
        canvas = PDFCanvas(id: "canvas1", url: "url1", pageNumber: 0, userDefinedScale: 1)
        try realm.write {
            realm.add(canvas)
        }
    }

    // test that model actually performs the commands
    // it'll run them in Realm as there's no remote updater provided
    @MainActor
    func testRunCommands_inRealm() async throws {
        try await model.runCommands([AddTagCommand(tagId: "tag1", name: "tag one")])
        realm.refresh()
        let tag = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"))
        XCTAssertEqual(tag.name, "tag one")
        XCTAssertFalse(tag.placeholder)
    }

    // test that model actually performs the commands
    // it'll run them via remote updater
    @MainActor
    func testRunCommands_byRemoteUpdater() async throws {
        let exp = expectation(description: "remote updater runCommands called")

        // simple remote updater that just fulfills given expectation on run commands
        class RemoteUpdater: ProjectModelRemoteUpdater {
            let exp: XCTestExpectation
            init(_ exp: XCTestExpectation) {
                self.exp = exp
            }

            func runCommands(_ commands: [Command], writer _: ProjectModelWriter) async throws {
                XCTAssertEqual(commands.count, 1)
                XCTAssertEqual(commands.first as? AddTagCommand,
                               AddTagCommand(tagId: "tag1", name: "tag one"))
                exp.fulfill()
            }
        }

        let remoteUpdater = RemoteUpdater(exp)
        model.remoteUpdater = remoteUpdater

        try await model.runCommands([AddTagCommand(tagId: "tag1", name: "tag one")])

        XCTAssertNil(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"))
        waitForExpectations(timeout: 1)
    }

    // test commands created for adding an upload for given collaboration id
    @MainActor
    func testAddUpload() throws {
        let tag1 = Tag(id: "tag1", name: "tag 1")
        try realm.write {
            realm.add(tag1)
        }

        // tag will be added
        let newTagViewModel = TagViewModel(newTagWithName: "tag 2")
        let commands =
            model._addUpload(uploadId: "upload1",
                             timestamp: 1234,
                             tags: [
                                 TagViewModel(
                                     id: tag1.id,
                                     name: tag1.name,
                                     lastApplied: tag1.lastApplied,
                                     usageCount: tag1.usageCount
                                 ),
                                 newTagViewModel,
                             ],
                             description: "upload description",
                             toCollaboration: "collaboration1")
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0] as? AddTagCommand, AddTagCommand(tagId: newTagViewModel.id, name: "tag 2"))
        let addUploadCmd = try XCTUnwrap(commands[1] as? AddUploadCommand)
        XCTAssertEqual(addUploadCmd, AddUploadCommand(
            uploadId: "upload1",
            correlationId: "upload1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: model.userId,
            timestamp: 1234,
            name: nil,
            uploadDescription: "upload description",
            url: nil,
            tagIds: ["tag1", newTagViewModel.id]
        ))
    }

    // test commands created for adding a photo at a given location
    // no detailed asserts for AddUploadCommand as it is tested by `testAddUpload`
    @MainActor
    func testAddPhoto_atLocation() async throws {
        let geometryId = generateRealmId()
        let commands = try await model.addPhotos(
            [PhotoToAdd(uploadId: "upload1", timestamp: 1234, cacheKey: "cacheKey", thumbnail: UIImage(),
                        height2Width: 1)],
            tags: [],
            description: "",
            at: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
            in: canvas,
            geometryId: geometryId
        )
        XCTAssertEqual(commands.count, 4)
        let addGeometryCmd = try XCTUnwrap(commands[0] as? AddGeometryCommand)
        XCTAssertEqual(addGeometryCmd, AddGeometryCommand(
            geometryId: geometryId,
            canvasId: "canvas1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        ))

        let addFeatureCmd = try XCTUnwrap(commands[1] as? AddFeatureCommand)
        XCTAssertEqual(addFeatureCmd, AddFeatureCommand(
            featureId: addFeatureCmd.featureId, // just take from the command as it's generated by addPhoto
            geometryId: geometryId,
            name: "",
            featureDescription: nil
        ))

        let addCollaborationCmd = try XCTUnwrap(commands[2] as? AddCollaborationCommand)
        XCTAssertEqual(addCollaborationCmd, AddCollaborationCommand(
            // just take from the command as it's generated by addPhoto
            collaborationId: addCollaborationCmd.collaborationId,
            featureId: addFeatureCmd.featureId,
            authorId: "user1",
            timestamp: 1234,
            name: "",
            collaborationDescription: nil,
            statusId: nil,
            tagIds: []
        ))

        let addUploadCmd = try XCTUnwrap(commands[3] as? AddUploadCommand)
        XCTAssertEqual(addUploadCmd.parentId, addCollaborationCmd.collaborationId)
        XCTAssertEqual(addUploadCmd.uploadId, "upload1")
        XCTAssertEqual(addUploadCmd.timestamp, 1234)
    }

    // test commands created for adding a photo for given geometry
    // no detailed asserts for AddUploadCommand as it is tested by `testAddUpload`
    @MainActor
    func testAddPhoto_forGeometry_geometryNotFound() async throws {
        do {
            _ = try await model.addPhotos(
                [PhotoToAdd(uploadId: "upload1", timestamp: 1234, cacheKey: "cacheKey", thumbnail: UIImage(),
                            height2Width: 1)],
                tags: [],
                description: "",
                toCollaborationForGeometryId: "geometry1"
            )
            XCTFail("should throw error")
        } catch {
            guard
                let error = error as? ModelError
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(error, ModelError.geometryNotFound)
        }
    }

    // test commands created for adding a photo for given geometry
    // no detailed asserts for AddUploadCommand as it is tested by `testAddUpload`
    @MainActor
    func testAddPhoto_forGeometry_noFeature() async throws {
        try realm.write {
            realm.add(Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            ))
        }
        let commands = try await model.addPhotos(
            [PhotoToAdd(uploadId: "upload1", timestamp: 1234, cacheKey: "cacheKey", thumbnail: UIImage(),
                        height2Width: 1)],
            tags: [],
            description: "",
            toCollaborationForGeometryId: "geometry1"
        )
        XCTAssertEqual(commands.count, 3)
        XCTAssertTrue(commands[0] is AddFeatureCommand)
        XCTAssertTrue(commands[1] is AddCollaborationCommand)
        XCTAssertTrue(commands[2] is AddUploadCommand)
    }

    // test commands created for adding a photo for given geometry
    // no detailed asserts for AddUploadCommand as it is tested by `testAddUpload`
    @MainActor
    func testAddPhoto_forGeometry_noCollaboration() async throws {
        // the geometry and feature is there
        try realm.write {
            let geometry = Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
            let feature = Feature(id: "feature1", name: "", description: "")
            realm.add([feature, geometry])
            geometry.features.insert(feature)
        }
        let commands = try await model.addPhotos(
            [PhotoToAdd(uploadId: "upload1", timestamp: 1234, cacheKey: "cacheKey", thumbnail: UIImage(),
                        height2Width: 1)],
            tags: [],
            description: "",
            toCollaborationForGeometryId: "geometry1"
        )
        XCTAssertEqual(commands.count, 2)
        XCTAssertTrue(commands[0] is AddCollaborationCommand)
        XCTAssertTrue(commands[1] is AddUploadCommand)
    }

    // test commands created for adding a photo for given geometry
    @MainActor
    func testAddPhoto_forGeometry() async throws {
        // the geometry, feature and collaboration are there
        try realm.write {
            let geometry = Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
            let feature = Feature(id: "feature1", name: "", description: "")
            let collaboration = Collaboration(id: "collaboration1", timestamp: 1, name: "", description: "")
            realm.add([feature, geometry, collaboration])
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
        let commands = try await model.addPhotos(
            [PhotoToAdd(uploadId: "upload1", timestamp: 1234, cacheKey: "cacheKey", thumbnail: UIImage(),
                        height2Width: 1)],
            tags: [],
            description: "",
            toCollaborationForGeometryId: "geometry1"
        )
        XCTAssertEqual(commands.count, 1)
        let addUploadCmd = try XCTUnwrap(commands[0] as? AddUploadCommand)
        XCTAssertEqual(addUploadCmd.parentId, "collaboration1")
        XCTAssertEqual(addUploadCmd.uploadId, "upload1")
        XCTAssertEqual(addUploadCmd.timestamp, 1234)
    }

    // test commands created for adding multiple photos for given geometry
    @MainActor
    func testAddPhotos_forGeometry() async throws {
        // the geometry, feature and collaboration are there
        try realm.write {
            let geometry = Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
            let feature = Feature(id: "feature1", name: "", description: "")
            let collaboration = Collaboration(id: "collaboration1", timestamp: 1, name: "", description: "")
            realm.add([feature, geometry, collaboration])
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
        let commands = try await model.addPhotos(
            [PhotoToAdd(uploadId: "upload1", timestamp: 1234, cacheKey: "cacheKey1", thumbnail: UIImage(),
                        height2Width: 1),
             PhotoToAdd(uploadId: "upload2", timestamp: 1235, cacheKey: "cacheKey2", thumbnail: UIImage(),
                        height2Width: 1),
             PhotoToAdd(uploadId: "upload3", timestamp: 1236, cacheKey: "cacheKey3", thumbnail: UIImage(),
                        height2Width: 1)],
            tags: [],
            description: "",
            toCollaborationForGeometryId: "geometry1"
        )
        XCTAssertEqual(commands.count, 3)
        let addUploadCmd1 = try XCTUnwrap(commands[0] as? AddUploadCommand)
        XCTAssertEqual(addUploadCmd1.parentId, "collaboration1")
        XCTAssertEqual(addUploadCmd1.uploadId, "upload1")
        XCTAssertEqual(addUploadCmd1.timestamp, 1234)
        let addUploadCmd2 = try XCTUnwrap(commands[1] as? AddUploadCommand)
        XCTAssertEqual(addUploadCmd2.parentId, "collaboration1")
        XCTAssertEqual(addUploadCmd2.uploadId, "upload2")
        XCTAssertEqual(addUploadCmd2.timestamp, 1235)
        let addUploadCmd3 = try XCTUnwrap(commands[2] as? AddUploadCommand)
        XCTAssertEqual(addUploadCmd3.parentId, "collaboration1")
        XCTAssertEqual(addUploadCmd3.uploadId, "upload3")
        XCTAssertEqual(addUploadCmd3.timestamp, 1236)
    }
}
