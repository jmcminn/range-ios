import CoreLocation
import Foundation
import UIKit

class CreateProjectViewModel: ObservableObject {
    /// Whether the create project flow is showing the list of autocompletes for addresses (instead of the map) in the step 1
    @Published private(set) var addressAutocompleteMode = false

    /// To be observed as a base for location/address updates (throttled and debounced as this can change very frequently when panning)
    @Published var cameraLocation: CLLocationCoordinate2D? = nil

    /// project location selected by user
    @Published var location: CLLocationCoordinate2D? = nil
    /// project address
    @Published var address: String = ""
    /// stored when entering the address autocompletion mode
    private var addressCopy: String = ""
    /// in addressAutocompleteMode these are the current autocompletes for the partial address
    @Published var placeAutocompletes: [PlaceAutocomplete] = []
    /// project name
    @Published var name: String = ""
    /// project description
    @Published var description: String = ""
    /// The type of the project to be presented in UI
    @Published var typeName: String? = nil
    /// The id of the project type to be used when creating the project
    @Published var typeId: String? = nil
    /// The name of the project to be presented in UI as the tag source
    @Published var tagSourceName: String? = nil
    /// The id of the project to be used for tag source
    @Published var tagSourceId: String? = nil

    /// whether the project is being currently created
    @Published var createProjectOngoing = false

    /// Change the step1 mode to address autocomplete (instead of showing the map)
    func enableAddressAutocompleteMode() {
        guard addressAutocompleteMode == false else { return }
        // store the address so it can be restored if user cancels the autocompletion
        addressCopy = address
        DispatchQueue.main.async {
            // main async to avoid "Publishing changes from within view updates is not allowed, this will cause undefined behavior."
            self.addressAutocompleteMode = true
        }
    }

    func cancelAddressAutocompleteMode() {
        guard addressAutocompleteMode == true else { return }
        DispatchQueue.main.async {
            // end editing the address search field
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            self.addressAutocompleteMode = false
            self.placeAutocompletes = []
            // restore the address
            self.address = self.addressCopy
        }
    }

    func selectPlaceAutocomplete(_ place: PlaceAutocomplete) {
        guard addressAutocompleteMode == true else { return }
        DispatchQueue.main.async {
            // order of operations is important, end editing needs to go first otherwise it could reenable address autocomplete
            // end editing the address search field
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            self.addressAutocompleteMode = false
            self.placeAutocompletes = []
            self.address = place.name
            self.location = place.center
        }
    }
}
