
import CoreLocation
import Kingfisher
@testable import Range
import RealmSwift
import Turf
import XCTest

class ProjectModelCommandsTest: ProjectModelTestCase {
    var canvas: Canvas!
    let coordinates = CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()

        canvas = Canvas(id: "canvas1", name: "")
        try realm.write {
            realm.add(canvas)
        }
    }

    // test that model actually performs the commands
    @MainActor
    func testRunCommand_inRealm() async throws {
        try await model.start()
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        let user1 = Participant(placeholderId: "user1")
        try realm.write {
            realm.add([collaboration1, user1])
        }
        let command = CreateCommentCommand.collaborationComment(
            collaborationId: "collaboration1",
            authorId: "user1",
            text: "text",
            isNote: false
        )
        try await model.run(command)
        realm.refresh()
        let comment = try XCTUnwrap(realm.object(ofType: Comment.self, forPrimaryKey: command.commentId))
        XCTAssertEqual(comment.text, "text")
    }

    // test that model passes the command to pending actions
    @MainActor
    func testRunCommand_addPendingAction() async throws {
        try await model.start()
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        let user1 = Participant(placeholderId: "user1")
        try realm.write {
            realm.add([collaboration1, user1])
        }
        let command = CreateCommentCommand.collaborationComment(
            collaborationId: "collaboration1",
            authorId: "user1",
            text: "text",
            isNote: false
        )
        try await model.run(command)

        XCTAssertEqual(pendingActionsModel.preparedActions.count, 1)
        let preparedAction = try XCTUnwrap(pendingActionsModel.preparedActions.first)
        XCTAssertEqual(preparedAction.projectId, model.projectId)
        guard case .createComment = preparedAction.command else {
            XCTFail("Wrong command")
            return
        }
    }

    // test commands created for adding a photo at a given location
    @MainActor
    func testCreatePhotoCollaboration() async throws {
        guard let command = try await model.createCollaboration(
            at: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
            in: canvas,
            withGeometryId: "geometry1",
            isTask: false,
            photosToAdd: [PhotoToAdd(
                timestamp: Date(timeIntervalSince1970: 1234),
                mediaKey: _mediaKey(uploadId: "upload1"),
                thumbnail: UIImage(),
                height2Width: 1, fileSize: 1024
            )],
            uploadTags: [TagViewModel(id: "tag1", name: "tag 1", usageCount: 0)],
            uploadDescription: "upload description",
            isDuplicate: false
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
            uploadTags: [.init(id: "tag1", name: "tag 1")],
            uploadDescription: "upload description",
            uploads: [.init(mediaKey: _mediaKey(uploadId: "upload1"), fileSize: 1024, imageHeightToWidth: 1)]
        ))
    }
}
