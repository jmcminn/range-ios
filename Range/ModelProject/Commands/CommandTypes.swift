import Foundation

/// Common types used in commands

/// Describing `Tag` data required for tag creation/update command
struct CommandTag: Codable, Equatable {
    var id: String
    var name: String

    /// to convert to other types
    var asFirestoreTagName: FirestoreTagName { FirestoreTagName(name: name) }
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
    var mediaKey: MediaKey
    var fileSize: Int64
    var name: String?
    var imageHeightToWidth: Double?
    var annotatedMediaKey: MediaKey?
    var annotations: Annotations?

    init(
        mediaKey: MediaKey,
        fileSize: Int64,
        name: String? = nil,
        imageHeightToWidth: Double? = nil,
        annotatedMediaKey: MediaKey? = nil,
        annotations: Annotations? = nil
    ) {
        self.mediaKey = mediaKey
        self.fileSize = fileSize
        self.name = name
        self.imageHeightToWidth = imageHeightToWidth
        self.annotatedMediaKey = annotatedMediaKey
        self.annotations = annotations
    }

    init(fromPhotoToAdd photoToAdd: PhotoToAdd) {
        mediaKey = photoToAdd.mediaKey
        fileSize = photoToAdd.fileSize
        name = photoToAdd.fileName
        imageHeightToWidth = photoToAdd.height2Width
        annotatedMediaKey = photoToAdd.annotatedMediaKey
        annotations = photoToAdd.annotations
    }
}
