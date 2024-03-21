import Foundation

var rangeIsClosed: Bool {
    get {
        // this will return false by default if nothing is stored in the defaults
        UserDefaults.standard.bool(forKey: "rangeIsClosed")
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "rangeIsClosed")
    }
}
