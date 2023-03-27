import SwiftUI

struct UserSettingsView: View {
    @EnvironmentObject var userSettings: UserSettings

    var body: some View {
        Form {
            Section(header: Text("Uploads")) {
                Toggle(isOn: $userSettings.uploadUsingCellular) {
                    Text("Allow uploads using cellular data")
                        .foregroundColor(.dynamic(.Neutral_04))
                        .padding(.top, 6)
                    Text("If disabled, only upload over wifi")
                        .font(.caption2)
                        .foregroundColor(.dynamic(.Neutral_05))
                        .padding(.bottom, 6)
                }
            }
            Section(header: Text("Camera")) {
                Toggle(isOn: $userSettings.saveImagesToDevice) {
                    Text("Save images to device")
                        .padding(.top, 6)
                        .foregroundColor(.dynamic(.Neutral_04))
                    Text("Photos are saved to the cloud and your device")
                        .font(.caption2)
                        .foregroundColor(.dynamic(.Neutral_05))
                        .padding(.bottom, 6)
                }
            }
            Section {
                Button(action: userSettings.signOutAction ?? {}) {
                    Text("Sign out")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.dynamic(.Neutral_04))
                        .contentShape(Rectangle()) // Hack to make the button trigger on the whole width and not only where the text is
                        .padding(.vertical, 6)
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
