import Firebase
import FirebaseAuth
import FirebaseCore
import OSLog
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        initiateFirebase()

        return true
    }

    private func initiateFirebase() {
        // firebase emulator enabled in Xcode environment variables.
        // Set to true in the "Range firebase emulator" scheme
        if ProcessInfo.processInfo.environment["firebaseEmulator"] == "true" {
            Logger.firebase.debug("Using firebase emulator")
            let options = FirebaseOptions(
                googleAppID: "1:572808558650:ios:a629bbc55b5cf1efc75d03",
                gcmSenderID: "572808558650"
            )
            options.clientID = "572808558650-559oeav7kr72noj7t0r3m0692ccvbj3p.apps.googleusercontent.com"
            options.apiKey = "AIzaSyBZlqvRODUUsw1A18j6iiPmKRA9EVEyXK0"
            options.projectID = "dev-jeff"
            options.storageBucket = "dev-jeff.appspot.com"
            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: "localhost", port: 9099)
            Database.database().useEmulator(withHost: "localhost", port: 9000)
        } else {
            Logger.firebase.debug("Using firebase project: \(FirebaseOptions.defaultOptions()?.projectID ?? "?")")
            FirebaseApp.configure()
        }

        // enable offline persistence for the database
        Database.database().isPersistenceEnabled = true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
