import Foundation
import RealmSwift

extension ActionCommand {
    var firebaseCommand: FirebaseCommand {
        switch self {
        case let .createPhotoMarker(cmd):
            return cmd
        case let .addUpload(cmd):
            return cmd
        }
    }

    var firestoreCommand: FirestoreCommand {
        switch self {
        case let .createPhotoMarker(cmd):
            return cmd
        case let .addUpload(cmd):
            return cmd
        }
    }
}
