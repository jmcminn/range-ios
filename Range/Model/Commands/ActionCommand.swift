import Foundation

/// This will be encoded as for example:
///  {
///    "addUpload": {
///     "_0": {
///         "uploadId": "c4bb0672-6854-4e33-9c4e-f59f9425038a",
///         "uploadDescription": "",
///         "collaborationId": "fb2e5d5b-997d-4740-b752-8ffb1a295462",
///         "userId": "718d800c-0174-4128-9c5b-6e47a76d3c0e",
///         "localUploadURL": "file:\/\/\/Users\/raho\/Library\/Developer\/CoreSimulator\/Devices\/E9BCFD00-C332-46AA-B5DC-7EFEB7C8747B\/data\/Containers\/Data\/Application\/A3B75765-E027-424D-AC61-CB135F4F5469\/Library\/Caches\/com.onevcat.Kingfisher.ImageCache.local-photos\/6953e9b263be1f8fe08a75d955be413c",
///         "tagViewModels": []
///     }
///   }
/// }
/// Not ideal, the "_0" level is not really needed and is responsible for the unnamed command associated value but to get rid of it
/// there would have to be a custom codable implementation that switches over all the cases and does the manual encoded, decode.
/// Not ideal either but at least it's keyed by the enum cases...
enum ActionCommand: Equatable, Codable {
    case createPhotoMarker(_ command: CreatePhotoMarkerCommand)
    case addUpload(_ command: AddUploadCommand)

    func applyLocally(writer: ProjectModelWriter) async throws {
        switch self {
        case let .createPhotoMarker(c):
            try await c.applyLocally(writer: writer)
        case let .addUpload(c):
            try await c.applyLocally(writer: writer)
        }
    }
}
