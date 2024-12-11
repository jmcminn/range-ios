import Foundation

/// Enumerates document types used in Range app
enum FirestoreDocumentType: String {
    case projectSummary
    case canvas = "canvases"
    case canvasSource = "canvasSources"
    case category = "categories"
    case collaboration = "collaborations"
    case comment = "comments"
    case geometry = "geometries"
    case invitation = "invitations"
    case participant = "participants"
    case suspendedParticipant = "suspendedParticipants"
    case presence = "presences"
    case statusName = "statusNames"
    case tagName = "tagNames"
    case update = "updates"
    case upload = "uploads"
}

/// Custom representation of firestore document.
/// Used instead of Firestore.DocumentReference to allow for mocking the firestore context for commands tests.
struct FirestoreDocument: Hashable, Equatable {
    var type: FirestoreDocumentType
    var id: String
    init(_ type: FirestoreDocumentType, _ id: String) {
        self.type = type
        self.id = id
    }

    // helper functions to shorten the code for creating `FirestoreDoc`
    static func canvas(_ id: String) -> FirestoreDocument { .init(.canvas, id) }
    static func canvasSource(_ id: String) -> FirestoreDocument { .init(.canvasSource, id) }
    static func collaboration(_ id: String) -> FirestoreDocument { .init(.collaboration, id) }
    static func comment(_ id: String) -> FirestoreDocument { .init(.comment, id) }
    static func geometry(_ id: String) -> FirestoreDocument { .init(.geometry, id) }
    static func participant(_ id: String) -> FirestoreDocument { .init(.participant, id) }
    static func suspendedParticipant(_ id: String) -> FirestoreDocument { .init(.suspendedParticipant, id) }
    static func presence(_ id: String) -> FirestoreDocument { .init(.presence, id) }
    static func statusName(_ id: String) -> FirestoreDocument { .init(.statusName, id) }
    static func tagName(_ id: String) -> FirestoreDocument { .init(.tagName, id) }
    static func update(_ id: String) -> FirestoreDocument { .init(.update, id) }
    static func upload(_ id: String) -> FirestoreDocument { .init(.upload, id) }
}
