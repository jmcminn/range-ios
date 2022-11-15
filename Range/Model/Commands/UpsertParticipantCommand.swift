import Foundation
import RealmSwift

/// Add or update the `Participant` in local Realm db.
struct UpsertParticipantCommand: LocalCommand, Equatable {
    let participantId: String
    var firstName: String
    var lastName: String
    var avatarUrl: URL?
    var email: String

    func apply(inRealm realm: Realm) throws {
        let participant = Participant(
            id: participantId,
            firstName: firstName,
            lastName: lastName,
            avatarUrl: avatarUrl,
            email: email
        )
        realm.add(participant, update: .modified)
    }
}
