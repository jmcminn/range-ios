import CoreLocation
import Foundation

class CreateProjectViewModel: ObservableObject {
    /// project location selected by user
    @Published var location: CLLocationCoordinate2D? = nil
    /// project address
    @Published var address: String? = nil
}
