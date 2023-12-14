import CoreLocation
import Foundation
import MapboxMaps

/// Custom Mapbox LocationProvider based on AppleLocationProvider but with added supported for simulated location
/// It wraps the AppleLocationProvider and exposes it's heading handling as is. For location it intercepts the location updates and observers
/// and adjusts the location when simulated location is provided, before passing the information to observers
class RangeLocationProvider: NSObject, LocationProvider, HeadingProvider, LocationObserver, CLLocationManagerDelegate {
    // Real location provider used for location, heading and authorization
    private let appleLocationProvider = AppleLocationProvider()

    // Last location received from AppleLocationProvider
    private var lastLocation: MapboxMaps.Location?
    // Observers registered for location updates
    private var locationObservers = NSHashTable<LocationObserver>.weakObjects()

    // for simulating the location
    private var realLocationWhenSimulationStarted: CLLocationCoordinate2D?
    private(set) var simulatedLocation: CLLocationCoordinate2D?

    // We need the instance of CLLocationManager to listen for and expose the authorizationStatus.
    // AppleLocationProvider is not exposing its instance...
    private let locationManager: CLLocationManager
    var onAuthorizationUpdate: (() -> Void)?
    var authorizationStatus: CLAuthorizationStatus { locationManager.authorizationStatus }

    override init() {
        locationManager = CLLocationManager()
        super.init()

        locationManager.delegate = self
        appleLocationProvider.addLocationObserver(for: self)
    }

    /// Set simulated location but still track the real location. Report the user movement but relative to the simulated location.
    /// Setting the simulatedLocation resets the realLocationWhenSimulationStarted so we have the new reference point the next time
    /// the real location is updated
    func setSimulatedLocation(_ location: CLLocationCoordinate2D) {
        realLocationWhenSimulationStarted = nil
        simulatedLocation = location
        // trigger the location update
        onLocationUpdateReceived(for: [])
    }

    /// Get the heading from proxied AppleLocationProvider
    var latestHeading: MapboxMaps.Heading? {
        appleLocationProvider.latestHeading
    }

    /// Add heading observer to the proxied AppleLocationProvider
    func add(headingObserver: MapboxMaps.HeadingObserver) {
        appleLocationProvider.add(headingObserver: headingObserver)
    }

    /// Remove heading observer from the proxied AppleLocationProvider
    func remove(headingObserver: MapboxMaps.HeadingObserver) {
        appleLocationProvider.remove(headingObserver: headingObserver)
    }

    /// Store LocationObserver
    public func addLocationObserver(for observer: LocationObserver) {
        locationObservers.add(observer)
    }

    public func removeLocationObserver(for observer: LocationObserver) {
        locationObservers.remove(observer)
    }

    public func getLastObservedLocation() -> MapboxMaps.Location? {
        lastLocation
    }

    /// When location update received from AppleLocationProvider we update the locations if we currently simulate the location and
    /// pass the updated ones to observers.
    /// When not simulating the location the locations are passed as is to the observers
    func onLocationUpdateReceived(for locations: [MapboxMaps.Location]) {
        var locationsToReport = locations

        if let simulatedLocation = simulatedLocation {
            // the location is simulated
            if let realLocationWhenSimulationStarted = realLocationWhenSimulationStarted {
                // report location relative to the realLocationWhenSimulationStarted
                locationsToReport = locations.map { location in
                    let latDelta = location.coordinate.latitude - realLocationWhenSimulationStarted.latitude
                    let lngDelta = location.coordinate.longitude - realLocationWhenSimulationStarted.longitude
                    let location = CLLocation(
                        latitude: simulatedLocation.latitude + latDelta,
                        longitude: simulatedLocation.longitude + lngDelta
                    )
                    return MapboxMaps.Location(clLocation: location)
                }
            } else {
                // report the simulated location but store the real one once when it's available
                realLocationWhenSimulationStarted = locations.last?.coordinate
                locationsToReport = [
                    MapboxMaps.Location(clLocation:
                        CLLocation(latitude: simulatedLocation.latitude,
                                   longitude: simulatedLocation.longitude)),
                ]
            }
        }

        if let location = locationsToReport.last {
            lastLocation = location
        }

        locationObservers.allObjects.forEach { $0.onLocationUpdateReceived(for: locationsToReport) }
    }

    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        onAuthorizationUpdate?()
    }
}
