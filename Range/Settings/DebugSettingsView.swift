import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var debugSettings: DebugSettings

    func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.dynamic(.Neutral_04))
                .contentShape(Rectangle()) // Hack to make the button trigger on the whole width and not only where the text is
                .padding(.vertical, 6)
        }.buttonStyle(.plain)
    }

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                actionButton(
                    title: "Toggle Light/Dark mode",
                    action: DebugSettings.toggleLightDarkMode
                )
                actionButton(
                    title: "Type Scale",
                    action: DebugSettings.showTypeScale
                )
            }
            Section(header: Text("App Start")) {
                Toggle(isOn: $debugSettings.openLastProjectOnStart) {
                    Text("Open last project on start")
                }
            }
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
