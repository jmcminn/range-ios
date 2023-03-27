import Firebase
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage
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
    }

    private func registerForNotifications(_ application: UIApplication) {
        Messaging.messaging().delegate = self

        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )

        application.registerForRemoteNotifications()
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

    func application(_: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any])
    {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: 1011 handle notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }

        // Print full message.
        print(userInfo)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions
    {
        let userInfo = notification.request.content.userInfo

        // TODO: 1011 handle notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // [START_EXCLUDE]
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        // [END_EXCLUDE]
        // Print full message.
        print(userInfo)

        // Change this to your preferred presentation option
        return [[.alert, .sound]]
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async
    {
        let userInfo = response.notification.request.content.userInfo

        // TODO: 1011 handle notification
        // [START_EXCLUDE]
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        // [END_EXCLUDE]
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print full message.
        print(userInfo)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        Logger.pushNotifications.debug("didReceiveRegistrationToken: \(fcmToken)")

//        let dataDict: [String: String] = ["token": fcmToken ?? ""]
//        NotificationCenter.default.post(
//            name: Notification.Name("FCMToken"),
//            object: nil,
//            userInfo: dataDict
//        )
        // Note: This callback is fired at each app startup and whenever a new token is generated.
        // TODO: 1012 react to this callback or just handle token on ProjectsModel start?
    }
}
