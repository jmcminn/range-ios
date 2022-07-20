import Foundation
import RealmSwift

struct AddParticipantCommand: Command {
    let participantId: String
    var firstName: String
    var lastName: String
    var avatarUrl: URL?
    var email: String

    func applyLocally(inRealm realm: Realm) throws {
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
