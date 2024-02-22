import Foundation

// TODO: 2610 get/set email notifications enabled in Knock
//        knockClient?.getUserPreferences(preferenceId: "default", completionHandler: { result in
//            switch result {
//            case let .success(preferences):
//                let emailNotifcationsEnabled: Bool
//                if let email = preferences.channel_types.email {
//                    switch email {
//                    case let .left(bool):
//                        emailNotifcationsEnabled = bool
//                    case .right:
//                        // unknown format, assume true
//                        emailNotifcationsEnabled = true
//                    }
//                } else {
//                    // if not present it means true (at least judging by the Knock preferences UI)
//                    emailNotifcationsEnabled = true
//                }
//                var updatedPreferences = preferences
//                updatedPreferences.channel_types.email = .left(!emailNotifcationsEnabled)
//                self.knockClient?.setUserPreferences(
//                    preferenceId: "default",
//                    preferenceSet: updatedPreferences,
//                    completionHandler: { updateResult in
//                        print("XXX update result", updateResult)
//                    }
//                )
//            case let .failure(error):
//                print("XXX prefs error:", error)
//            }
//        })
