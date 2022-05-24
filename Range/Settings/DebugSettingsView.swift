import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var debugSettings: DebugSettings

    var body: some View {
        Form {
            Section(header: Text("Photo pin selection")) {
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
