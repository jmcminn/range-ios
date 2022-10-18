import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var debugSettings: DebugSettings

    var body: some View {
        Form {
            Section(header: Text("Canvas")) {
                Toggle(isOn: $debugSettings.nativeViewsForPins) {
                    Text("Use native views for pins")
                }
            }
            Section(header: Text("Collaboration window")) {
                Toggle(isOn: $debugSettings.feedSortedAscendingByTimestamp) {
                    Text("Feed items sorted ascending by timestamp")
                }
                Toggle(isOn: $debugSettings.dynamicImageHeightInCollabFeed) {
                    Text("Dynamic image height in the feed")
                }
            }
            Section(header: Text("Photo pin selection"), footer: Text("App version: \(debugSettings.appVersion)")) {
                Toggle(isOn: $debugSettings.centerCanvasOnPinSnap) {
                    Text("Center canvas on pin snap:")
                }
                Toggle(isOn: $debugSettings.hapticFeedbackOnPinTapSelection) {
                    Text("Haptic feedback on tap pin selection:")
                }
            }
        }
    }
}

struct DebugSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
    }
}
