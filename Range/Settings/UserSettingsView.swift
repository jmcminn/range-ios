import SwiftUI

struct UserSettingsView: View {
    @EnvironmentObject var userSettings: UserSettings

    var body: some View {
        Form {
            Section(header: Text("Uploads")) {
                Toggle(isOn: $userSettings.uploadUsingCellular) {
                    Text("Allow uploads using cellular data")
                        .foregroundColor(.dynamicColor(light: .Neutral_07, dark: .Neutral_04))
                    Text("If disabled, only upload over wifi")
                        .font(.caption2)
                        .foregroundColor(.dynamicColor(light: .Neutral_06, dark: .Neutral_05))
                }
            }
            Section(header: Text("Camera")) {
                Toggle(isOn: $userSettings.saveImagesToDevice) {
                    Text("Save Images to Device")
                        .foregroundColor(.dynamicColor(light: .Neutral_07, dark: .Neutral_04))
                    Text("Photos are saved to the cloud and your device")
                        .font(.caption2)
                        .foregroundColor(.dynamicColor(light: .Neutral_06, dark: .Neutral_05))
                }
            }
            Section {
                Button(action: userSettings.signOutAction ?? {}) {
                    Text("Sign out")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.dynamicColor(light: .Neutral_07, dark: .Neutral_04))
                        .contentShape(Rectangle()) // Hack to make the button trigger on the whole width and not only where the text is
                }.buttonStyle(.plain)
            }
        }
    }
}

struct UserSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UserSettingsView()
    }
}
