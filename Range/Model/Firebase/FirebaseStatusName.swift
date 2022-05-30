import Foundation

/// Represents the `Status` (`projects/details/statusNames` path in Firebase)
///
/// Encoded as:
///
///     {
///         "id"         : "0521fccf-3799-4786-aab1-e5e5108c0807",
///         "name"       : "In Progress",
///         "color"      : "#5D81FF",
///         "isInitial"  : true,
///         "isCompleted": false,
///     }
struct FirebaseStatusName: Codable {
    let id: String
    let name: String
    let color: String
    let isInitial: Bool
    let isCompleted: Bool

//    The decoded Status
    var status: Status {
        Status(id: id, name: name, hexColor: color, isInitial: isInitial, isCompleted: isCompleted)
    }
}
