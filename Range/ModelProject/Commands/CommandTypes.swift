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
    var id: String
    var fileType: Upload.FileType
    var fileSize: Int64
    var name: String?
    var imageHeightToWidth: Double?
    var annotations: Annotations?

    init(
        id: String,
        fileType: Upload.FileType,
        fileSize: Int64,
        name: String? = nil,
        imageHeightToWidth: Double? = nil,
        annotations: Annotations? = nil
    ) {
        self.id = id
        self.fileType = fileType
        self.fileSize = fileSize
        self.name = name
        self.imageHeightToWidth = imageHeightToWidth
        self.annotations = annotations
    }

    init(fromPhotoToAdd photoToAdd: PhotoToAdd) {
        id = photoToAdd.mediaKey.uploadId
        fileType = photoToAdd.mediaKey.fileType
        fileSize = photoToAdd.fileSize
        name = photoToAdd.fileName
        imageHeightToWidth = photoToAdd.height2Width
        annotations = photoToAdd.annotations
    }
}
