import SwiftUI

struct AnnotationsDevSettingsView: View {
    @EnvironmentObject var settings: AnnotationsDevSettings

    var body: some View {
        Form {
            Section(header: Text("Scribble tool")) {
                Toggle(isOn: $settings.simplifyScribbleLine) {
                    Text("Simplify scribble polyline")
                    Text(
                        "Reduce the number of polyline segments resulting from user pan gesture using the Douglas-Peucker algorithm"
                    )
                    .font(.caption)
                    .foregroundColor(.dynamic(.Neutral_05))
                    .padding(.bottom, 6)
                }
                Toggle(isOn: $settings.interpolateScribbleLine) {
                    Text("Interpolate scribble polyline")
                    Text("Interpolate points from user gesture with bezier curves using Catmull-Rom algorithm")
                        .font(.caption)
                        .foregroundColor(.dynamic(.Neutral_05))
                        .padding(.bottom, 6)
                }
            }
        }
    }
}

struct AnnotationsDevSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationsDevSettingsView()
    }
}
