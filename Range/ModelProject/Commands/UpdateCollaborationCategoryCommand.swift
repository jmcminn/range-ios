import FirebaseFirestore
import Foundation
import RealmSwift

/// Update category for given Collaboration
struct UpdateCollaborationCategoryCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.update: [collaborationId]]
    }

    let collaborationId: String
    let categoryId: String

    init(collaborationId: String, categoryId: String) {
        self.collaborationId = collaborationId
        self.categoryId = categoryId
    }
}

/// Update in local Realm db
extension UpdateCollaborationCategoryCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        guard let category = realm.object(ofType: Category.self, forPrimaryKey: categoryId) else {
            throw ModelError.categoryNotFound
        }
        collaboration.category = category
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationCategoryCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    var functionData: [String: Any?]? {
        [
            "collaborationId": collaborationId,
            "categoryId": categoryId,
        ]
    }
}
