
import CoreLocation
import Kingfisher
@testable import Range
import RealmSwift
import Turf
import XCTest

class ProjectModelCommandsTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!
    var canvas: PDFCanvas!
    let coordinates = CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)

    @MainActor
    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
        canvas = PDFCanvas(
            id: "canvas1",
            name: "",
            pageNumber: 0,
            sheetNumber: nil,
            userDefinedScale: 1
        )
        try realm.write {
            realm.add(canvas)
        }
    }

    // test that model actually performs the commands
    @MainActor
    func testRunCommand_inRealm() async throws {
        try await model.start()
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([collaboration1, user1])
        }
        let command = CreateCollaborationCommentCommand(
            commentId: "comment1",
            collaborationId: "collaboration1",
            authorId: "user1",
            text: "text",
            isNote: false
        )
        try await model.run(command)
        realm.refresh()
        let comment = try XCTUnwrap(realm.object(ofType: Comment.self, forPrimaryKey: "comment1"))
        XCTAssertEqual(comment.text, "text")
    }

    // test that model passes the command to pending actions
    @MainActor
    func testRunCommand_addPendingAction() async throws {
        try await model.start()
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([collaboration1, user1])
        }
        let command = CreateCollaborationCommentCommand(
            commentId: "comment1",
            collaborationId: "collaboration1",
            authorId: "user1",
            text: "text",
            isNote: false
        )
        try await model.run(command)

        XCTAssertEqual(pendingActionsModel.preparedActions.count, 1)
        let preparedAction = try XCTUnwrap(pendingActionsModel.preparedActions.first)
        XCTAssertEqual(preparedAction.projectId, model.projectId)
        guard case .createCollaborationComment = preparedAction.command else {
            XCTFail("Wrong command")
            return
        }
    }

    // test commands created for adding a photo at a given location
    @MainActor
    func testCreatePhotoCollaboration() async throws {
        guard let command = try await model.createPhotoCollaboration(
            [PhotoToAdd(
                uploadId: "upload1",
                timestamp: Date(timeIntervalSince1970: 1234),
                cacheKey: "cacheKey",
                thumbnail: UIImage(),
                height2Width: 1
            )],
            tags: [TagViewModel(id: "tag1", name: "tag 1", usageCount: 0)],
            description: "upload description",
            at: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
            in: canvas,
            withGeometryId: "geometry1"
        ) as? CreateCollaborationCommand else {
            XCTFail("addPhotos failed")
            return
        }
        XCTAssertEqual(command, CreateCollaborationCommand(
            authorId: "user1",
            canvasId: "canvas1",
            geometryId: "geometry1",
            featureId: command.featureId,
            collaborationId: command.collaborationId,
            coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
            tags: [.init(id: "tag1", name: "tag 1")],
            uploadDescription: "upload description",
            uploads: [.init(id: "upload1", imageHeightToWidth: 1)]
        ))
    }

    // test commands created for adding photos to collaboration
    @MainActor
    func testAddPhotosToCollaboration_geometryNotFound() async throws {
        do {
            _ = try await model.addPhotos(
                [PhotoToAdd(uploadId: "upload1", timestamp: Date.now, cacheKey: "cacheKey", thumbnail: UIImage(),
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

    // test commands created for adding photos to collaboration
    @MainActor
    func testAddPhotosToCollaboration_noFeature() async throws {
        try realm.write {
            realm.add(Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            ))
        }
        do {
            _ = try await model.addPhotos(
                [PhotoToAdd(uploadId: "upload1", timestamp: Date.now, cacheKey: "cacheKey", thumbnail: UIImage(),
                            height2Width: 1)],
                tags: [], description: "", toCollaborationForGeometryId: "geometry1"
            )
            XCTFail("should throw error")
        } catch {
            guard
                let error = error as? ModelError
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(error, ModelError.featureNotFound)
        }
    }

    // test commands created for adding photos to collaboration
    @MainActor
    func testAddPhotosToCollaboration_noCollaboration() async throws {
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
        do {
            _ = try await model.addPhotos(
                [PhotoToAdd(uploadId: "upload1", timestamp: Date.now, cacheKey: "cacheKey", thumbnail: UIImage(),
                            height2Width: 1)],
                tags: [],
                description: "",
                toCollaborationForGeometryId: "geometry1"
            )
        } catch {
            guard
                let error = error as? ModelError
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(error, ModelError.collaborationNotFound)
        }
    }

    // test commands created for adding photos to collaboration
    @MainActor
    func testAddPhotosToCollaboration_successful() async throws {
        // the geometry, feature and collaboration are there
        try realm.write {
            let geometry = Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
            let feature = Feature(id: "feature1", name: "", description: "")
            let collaboration = Collaboration(id: "collaboration1", timestamp: Date.now, name: "", description: "")
            realm.add([feature, geometry, collaboration])
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
        let command = try await model.addPhotos(
            [
                PhotoToAdd(uploadId: "upload1", timestamp: Date(timeIntervalSince1970: 1234), cacheKey: "cacheKey1",
                           thumbnail: UIImage(),
                           height2Width: 1),
                PhotoToAdd(
                    uploadId: "upload2",
                    timestamp: Date(timeIntervalSince1970: 1235),
                    cacheKey: "cacheKey2",
                    thumbnail: UIImage(),
                    height2Width: 1.2
                ),
                PhotoToAdd(
                    uploadId: "upload3",
                    timestamp: Date(timeIntervalSince1970: 1236),
                    cacheKey: "cacheKey3",
                    thumbnail: UIImage(),
                    height2Width: 1.3
                ),
            ],
            tags: [TagViewModel(id: "tag1", name: "tag 1", usageCount: 0)],
            description: "upload description",
            toCollaborationForGeometryId: "geometry1"
        )
        XCTAssertEqual(command as? AddUploadsToCollaborationCommand, AddUploadsToCollaborationCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            tags: [.init(id: "tag1", name: "tag 1")],
            uploadDescription: "upload description",
            uploads: [
                .init(id: "upload1", imageHeightToWidth: 1),
                .init(id: "upload2", imageHeightToWidth: 1.2),
                .init(id: "upload3", imageHeightToWidth: 1.3),
            ]
        ))
    }
}
