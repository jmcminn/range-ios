import CoreLocation
import Foundation

class CreateProjectViewModel: ObservableObject {
    /// project location selected by user
    @Published var location: CLLocationCoordinate2D? = nil
    /// project address
    @Published var address: String? = nil
    /// project name
    @Published var name: String = ""
    /// project description
    @Published var description: String = ""
    /// The type of the project to be presented in UI
    @Published var typeName: String? = nil
    /// The id of the project to be used when creating the project
    @Published var typeId: String? = nil
    /// The name of the project to be presented in UI as the tag source
    @Published var tagSourceName: String? = nil
    /// The id of the project to be used for tag source
    @Published var tagSourceId: String? = nil
}
