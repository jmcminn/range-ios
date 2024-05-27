@testable import Range
import XCTest

final class PendingActionsV1MigrationTest: XCTestCase {
    func test_migrateV1() throws {
        let jsonEncoder = JSONEncoder()
        let jsonDecoder = JSONDecoder()

        // given multiple commands in v1 version
        let v1Actions: [any Codable] = [
            Action(projectId: "p1", command:
                DeleteUploadCommand(uploadId: "upload1")),
            V1Action(projectId: "p1", command:
                AddUploadsToCollaborationCommand(
                    authorId: "user1", collaborationId: "collaboration1", tags: [], uploads: [
                        CommandUpload(
                            mediaKey: _mediaKey(projectId: "project1", uploadId: "upload2"),
                            fileSize: 10
                        ),
                        CommandUpload(
                            mediaKey: _mediaKey(projectId: "project1", uploadId: "upload3"),
                            fileSize: 20
                        ),
                    ]
                )),
            Action(projectId: "p1", command:
                UpdateCollaborationNameCommand(collaborationId: "collaboration1", name: "collab name")),
            V1Action(projectId: "p1", command:
                AddUploadsToCollaborationCommand(
                    authorId: "user1", collaborationId: "collaboration1",
                    tags: [CommandTag(id: "tag1", name: "tag name 1")],
                    uploadDescription: "upload description",
                    uploads: [
                        CommandUpload(mediaKey: _mediaKey(projectId: "project1", uploadId: "upload3"), fileSize: 10),
                    ],
                    correlationId: "upload2"
                )),
        ]
        let v1Data = try v1Actions.map { try jsonEncoder.encode($0) }

        // when converted to v2
        let data = _migrateV1PendingActions(data: v1Data)
        let actions = try data.map { try jsonDecoder.decode(Action.self, from: $0) }
        let commands = actions.compactMap { $0.command.localCommand as? Command }

        // then AddUploadsToCollaborationCommand is converted to [CreateUploadCommand]
        XCTAssertEqual(commands[0] as? DeleteUploadCommand, DeleteUploadCommand(uploadId: "upload1"))
        XCTAssertEqual(commands[1] as? CreateUploadCommand, CreateUploadCommand(
            authorId: "user1", collaborationId: "collaboration1", tags: [], upload:
            CommandUpload(mediaKey: _mediaKey(projectId: "project1", uploadId: "upload2"), fileSize: 10)
        ))
        XCTAssertEqual(commands[2] as? CreateUploadCommand, CreateUploadCommand(
            authorId: "user1", collaborationId: "collaboration1", tags: [], upload:
            CommandUpload(
                mediaKey: _mediaKey(projectId: "project1", uploadId: "upload3"),
                fileSize: 20
            )
        ))
        XCTAssertEqual(commands[3] as? UpdateCollaborationNameCommand, UpdateCollaborationNameCommand(
            collaborationId: "collaboration1", name: "collab name"
        ))
        XCTAssertEqual(commands[4] as? CreateUploadCommand, CreateUploadCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            tags: [
                CommandTag(id: "tag1", name: "tag name 1"),
            ],
            uploadDescription: "upload description",
            upload: CommandUpload(
                mediaKey: _mediaKey(
                    projectId: "project1",
                    uploadId: "upload3"
                ),
                fileSize: 10
            ),
            correlationId: "upload2"
        ))
    }
}
