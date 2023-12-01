import CoreLocation
import Foundation
import MapboxMaps

/// Custom Mapbox LocationProvider based on AppleLocationProvider but with added supported for simulated location
class RangeLocationProvider: NSObject {
    private var locationProvider: CLLocationManager
    private var privateLocationProviderOptions: LocationOptions {
        didSet {
            locationProvider.distanceFilter = privateLocationProviderOptions.distanceFilter
            locationProvider.desiredAccuracy = privateLocationProviderOptions.desiredAccuracy
            locationProvider.activityType = privateLocationProviderOptions.activityType
        }
    }

    private weak var delegate: LocationProviderDelegate?

    public var headingOrientation: CLDeviceOrientation {
        didSet { locationProvider.headingOrientation = headingOrientation }
    }

    private var realLocationWhenSimulationStarted: CLLocationCoordinate2D?
    private(set) var simulatedLocation: CLLocationCoordinate2D?

    var onAuthorizationUpdate: (() -> Void)?

    override init() {
        locationProvider = CLLocationManager()
        privateLocationProviderOptions = LocationOptions()
        headingOrientation = locationProvider.headingOrientation
        super.init()
        locationProvider.delegate = self
    }

    /// Set simulated location but still track the real location. Report the user movement but relative to the simulated location.
    /// Setting the simulatedLocation resets the realLocationWhenSimulationStarted so we have the new reference point the next time
    /// the real location is updated
    func setSimulatedLocation(_ location: CLLocationCoordinate2D) {
        simulatedLocation = location
        // trigger the location update
        locationManager(locationProvider, didUpdateLocations: [])
    }
}

extension RangeLocationProvider: LocationProvider {
    public var locationProviderOptions: LocationOptions {
        get { privateLocationProviderOptions }
        set { privateLocationProviderOptions = newValue }
    }

    public var authorizationStatus: CLAuthorizationStatus {
        locationProvider.authorizationStatus
    }

    public var accuracyAuthorization: CLAccuracyAuthorization {
        locationProvider.accuracyAuthorization
    }

    public var heading: CLHeading? {
        locationProvider.heading
    }

    public func setDelegate(_ delegate: LocationProviderDelegate) {
        self.delegate = delegate
    }

    public func requestAlwaysAuthorization() {
        locationProvider.requestAlwaysAuthorization()
    }

    public func requestWhenInUseAuthorization() {
        locationProvider.requestWhenInUseAuthorization()
    }

    public func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String) {
        locationProvider.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey)
    }

    public func startUpdatingLocation() {
        locationProvider.startUpdatingLocation()
    }

    public func stopUpdatingLocation() {
        locationProvider.stopUpdatingLocation()
    }

    public func startUpdatingHeading() {
        locationProvider.startUpdatingHeading()
    }

    public func stopUpdatingHeading() {
        locationProvider.stopUpdatingHeading()
    }

    public func dismissHeadingCalibrationDisplay() {
        locationProvider.dismissHeadingCalibrationDisplay()
    }
}

extension RangeLocationProvider: CLLocationManagerDelegate {
    public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let simulatedLocation = simulatedLocation {
            // the location is simulated
            if let realLocationWhenSimulationStarted = realLocationWhenSimulationStarted,
               let realLocation = locations.last
            {
                // report location relative to the realLocationWhenSimulationStarted
                let latDelta = realLocation.coordinate.latitude - realLocationWhenSimulationStarted.latitude
                let lngDelta = realLocation.coordinate.longitude - realLocationWhenSimulationStarted.longitude
                let location = CLLocation(
                    latitude: simulatedLocation.latitude + latDelta,
                    longitude: simulatedLocation.longitude + lngDelta
                )
                delegate?.locationProvider(self, didUpdateLocations: [location])
            } else {
                // report the simulated location but store the real one once when it's available
                realLocationWhenSimulationStarted = locations.last?.coordinate
                let location = CLLocation(latitude: simulatedLocation.latitude, longitude: simulatedLocation.longitude)
                delegate?.locationProvider(self, didUpdateLocations: [location])
            }

        } else {
            // no simulation
            delegate?.locationProvider(self, didUpdateLocations: locations)
        }
    }

    public func locationManager(_: CLLocationManager, didUpdateHeading heading: CLHeading) {
        delegate?.locationProvider(self, didUpdateHeading: heading)
    }

    public func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        delegate?.locationProvider(self, didFailWithError: error)
    }

    public func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        delegate?.locationProviderDidChangeAuthorization(self)
        onAuthorizationUpdate?()
    }

    public func locationManagerShouldDisplayHeadingCalibration(_: CLLocationManager) -> Bool {
        false
    }
}
