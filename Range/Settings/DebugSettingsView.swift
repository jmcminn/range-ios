import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var debugSettings: DebugSettings

    var body: some View {
        Form {
            Section(header: Text("Photo pin selection")) {
                Toggle(isOn: $debugSettings.centerScreenOnPinSnap) {
                    Text("Center screen on pin snap:")
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
