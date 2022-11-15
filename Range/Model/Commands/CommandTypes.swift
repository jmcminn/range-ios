import Foundation

/// Common types used in commands

/// Describing `Tag` data required for tag creation/update command
struct CommandTag: Codable, Equatable {
    var id: String
    var name: String

    /// to convert to other types
    var asFirestoreTagName: FirebaseTagName { FirebaseTagName(name: name) }
    var asTag: Tag { Tag(id: id, name: name) }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// to init from the TagViewModel
    init(fromViewModel tagViewModel: TagViewModel) {
        id = tagViewModel.id
        name = tagViewModel.name
    }
}

/// `Upload` data required for upload creation
struct CommandUpload: Codable, Equatable {
    var id: String
    var imageHeightToWidth: Double

    init(id: String, imageHeightToWidth: Double) {
        self.id = id
        self.imageHeightToWidth = imageHeightToWidth
    }

    init(fromPhotoToAdd photoToAdd: PhotoToAdd) {
        id = photoToAdd.uploadId
        imageHeightToWidth = photoToAdd.height2Width
    }
}
