import Foundation
import RealmSwift

/// Update tags for given Upload
struct UpdateUploadTagsCommand: Command, Equatable {
    let uploadId: String
    var tagIds: [String]

    func apply(inRealm _: Realm) throws {
        // this command is not run locally, only applied to firestore. Below is the implementation
        // proposal in case we ever need it locally (if we have offline support for the model updates)
        // needs a test case if enabled
        fatalError("apply UpdateUploadTagsCommand in Realm has not been implemented")
//        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else { return }
//
//        // remove the upload from the tags it was attached to and is not anymore
//        // for fast lookup
//        let tagIdsSet = Set(tagIds)
//        for tag in upload.tags {
//            if !tagIdsSet.contains(tag.id) {
//                // updated tags don't contain this tag, remove the object from it
//                tag.uploads.remove(upload)
//            }
//        }
//
//        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
//        upload.tags.append(objectsIn: tags)
//        tags.forEach { $0.uploads.insert(upload) }
    }
}
