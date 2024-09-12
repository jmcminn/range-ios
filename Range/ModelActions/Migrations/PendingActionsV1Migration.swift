import Foundation
import RealmSwift
import OSLog

/// Accepts data in v1 version and returns v2 version
/// The AddUploadsToCollaborationCommand is migrated to [CreateUploadCommand], the rest of commands are unchanged
func _migrateV1PendingActions(data: [Data]) -> [Data] {
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    return Array(data
        .map { data in
            do {
                let action = try jsonDecoder.decode(V1Action.self, from: data)
                switch action.command {
                case let .addUploadsToCollaboration(command):
                    let v2Commands = command.toV2Commands()
                    let v2Actions = try v2Commands.map { createUploadCommand in
                        let v2Action = Action(projectId: action.projectId, command: createUploadCommand)
                        return try jsonEncoder.encode(v2Action)
                    }
                    Logger.pendingActions.info("AddUploadsToCollaborationCommand migrated to \(v2Commands)")
                    return v2Actions
                }
            } catch {
                return [data]
            }
        }
        .joined())
}

/// Lists commands to be converted from v1 to v2
/// It mimics the Action struct but has a v1 vartiant of command, so we can read it using JSONDecoder and convert to v2
struct V1Action: Codable {
    var projectId: String
    var command: V1ActionCommand
    
    init(projectId: String, command: Command) {
        self.projectId = projectId
        self.command = V1ActionCommand(command)
    }
}

enum V1ActionCommand: Codable {
    case addUploadsToCollaboration(AddUploadsToCollaborationCommand)
    init(_ c: Any) {
        switch c {
        case let c as AddUploadsToCollaborationCommand: self = .addUploadsToCollaboration(c)
        default: fatalError("ActionCommand not implemented for \(c)")
        }
    }
}

// The AddUploadsToCollaborationCommand to be migrated to [CreateUploadCommand]
struct AddUploadsToCollaborationCommand: Command, Codable {
    var operations: [CommandOperationType : [String]] {
        [.create: [collaborationId]]
    }
    
    var authorId: String
    var collaborationId: String
    var tags: [CommandTag]
    var uploadDescription: String?
    var uploads: [CommandUpload]
    var correlationId: String?

    func toV2Commands() -> [CreateUploadCommand] {
        uploads.map { upload in
            CreateUploadCommand(
                authorId: authorId,
                collaborationId: collaborationId,
                tags: tags,
                uploadDescription: uploadDescription,
                upload: upload,
                correlationId: correlationId
            )
        }
    }
}
