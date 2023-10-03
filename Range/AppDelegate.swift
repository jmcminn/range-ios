import Firebase
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import FirebaseStorage
import GoogleSignIn
import OSLog
import Sentry
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.message_id"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupAnalytics()

        setupAppearance()

        initiateSentry()

        initiateFirebase()

        registerForNotifications(application)

        return true
    }

    /// Set appearance for UI elements
    private func setupAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = .dynamic(.Neutral_10)
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .dynamic(.Neutral_04)
        tabBarAppearance.stackedLayoutAppearance.normal
            .titleTextAttributes = [.foregroundColor: UIColor.dynamic(.Neutral_04)]
        UITabBar.appearance().standardAppearance = tabBarAppearance
//        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = .Primary_Blue_04

        // search bar customization
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes(
            [.foregroundColor: UIColor.Primary_Blue_04], for: .normal
        )
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = .dynamic(.Neutral_09)
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
            .defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.dynamic(.Neutral_04)]
    }

    private func initiateSentry() {
        guard let sentryEnv: String = try? AppConfiguration.value(for: "SentryEnv"), sentryEnv.isEmpty == false else {
            Logger.sentry.debug("No sentry environment provided! Not starting sentry")
            return
        }
        Logger.sentry.debug("Starting sentry for '\(sentryEnv)' environment")

        SentrySDK.start { options in
            options.dsn = "https://5c3c709066fb4b5e897f79841727332a@o1384740.ingest.sentry.io/4504475534032896"
            // for debugging
//            options.debug = true // Enabled debug when first installing is always helpful
//            options.diagnosticLevel = .warning
            options.environment = sentryEnv
        }
    }

    private func initiateFirebase() {
        // firebase emulator enabled in the "Debug firebase emulator" configuration
        // in the `FIREBASE_PROJECT` custom build setting
        // if set to "emulator" then run on emulator, otherwise on the configuration
        // provided in GoogleService-Info.plist
        let firebaseProject: String = try! AppConfiguration.value(for: "FirebaseProject")
        if firebaseProject == "emulator" {
            Logger.firebase.debug("Using firebase emulator")
            let options = FirebaseOptions(
                googleAppID: "1:1015622064814:ios:de6eac6d62f0f087b7eb3f",
                gcmSenderID: "1015622064814"
            )
            options.clientID = "1015622064814-folagjdh01kajtaset6van9euommo3pk.apps.googleusercontent.com"
            options.apiKey = "AIzaSyABylJo9Mn-jah1wTS6MEZfPNsMkH9QG5Q"
            options.projectID = "development-18fcf"
            options.storageBucket = "development-18fcf.appspot.com"
            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: "localhost", port: 9099)
            Storage.storage().useEmulator(withHost: "localhost", port: 9199)
            let settings = Firestore.firestore().settings
            settings.host = "localhost:9001"
            settings.isPersistenceEnabled = false
            settings.isSSLEnabled = false
            Firestore.firestore().settings = settings
            Functions.functions(region: "us-west2").useEmulator(withHost: "127.0.0.1", port: 5001)
        } else {
            Logger.firebase.debug("Using firebase project: \(FirebaseOptions.defaultOptions()?.projectID ?? "?")")

            // use debug app check in simulator (https://firebase.google.com/docs/app-check/ios/debug-provider)
            // and real provider in device builds (https://firebase.google.com/docs/app-check/ios/app-attest-provider#swift)
            #if targetEnvironment(simulator)
                AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
                AppCheck.setAppCheckProviderFactory(AppAttestAppCheckProviderFactory())
            #endif

            FirebaseApp.configure()
            // ACHTUNG: isPersistenceEnabled must be true for Firestore. Otherwise it won't notify about
            // removed objects while the app was not running
        }

        setupRemoteConfig()
    }

    private func registerForNotifications(_: UIApplication) {
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        UNUserNotificationCenter.current().delegate = self
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

    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Notification received when the app is open, decide how to present it
    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent _: UNNotification) async -> UNNotificationPresentationOptions
    {
        // show the banner in the app, do not add to notification center (would require .list option)
        [[.banner, .sound]]
    }

    /// User tapped on the notification when the app was open
    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        Logger.pushNotifications.debug("notification: \(response.notification.request.content)")
        guard let projectId = userInfo["p"] as? String else {
            Logger.pushNotifications.warning("no projectId (p) in notification")
            return
        }

        Logger.pushNotifications.debug("open project \(projectId) from notification")

        // take the first scene delegage, we only have one
        guard let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate else {
            return
        }
        let projectName = userInfo["pName"] as? String ?? "project from notification"
        sceneDelegate.showProjectTaskList(projectId: projectId, projectName: projectName)
    }
}
