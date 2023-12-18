@_spi(Experimental) import MapboxMaps
import SwiftUI

struct CreateProjectStep1View: View {
    let cancelAction: () -> Void
    let nextAction: () -> Void

    let mapStyle = MapStyle(uri: StyleURI.satelliteStreets)
    let puck2D = Puck2D(bearing: .heading)
        .topImage(UIImage().addCircleBackground(
            bgSize: CGSize(width: 16, height: 16), bgColor: .BlueDotBlue, strokeColor: .BlueDotBlue
        ))
        .shadowImage(UIImage(named: "bluedot_background"))
        .bearingImage(nil)

    private var mapView: some View {
        Map(initialViewport: .followPuck(zoom: 16)) {
            puck2D
        }
        .mapStyle(mapStyle)
        .ignoresSafeArea()
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Step 1: ").foregroundColor(.dynamic(.Neutral_05)) +
                    Text("Set Project Location").foregroundColor(.dynamic(.Neutral_04))

                RepresentedSearchView()
                    .placeholder("Search for, or select a location...")
                    .frame(height: 48)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .background(Color.dynamic(.Neutral_10))
            Divider()
                .frame(height: 1)
                .background(Color.dynamic(.Neutral_07))
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Spacer()
            Divider()
                .frame(height: 1)
                .background(Color.dynamic(.Neutral_07))
            HStack(spacing: 16) {
                Button("Cancel", action: cancelAction)
                    .buttonStyle(._gray)
                Button("Next", action: nextAction)
                    .buttonStyle(._blue)
            }
            .padding(16)
            .background(Color.dynamic(.Neutral_10))
        }
    }

    var body: some View {
        ZStack {
            mapView
            topBar
            bottomBar
        }
    }
}

#Preview {
    CreateProjectStep1View(cancelAction: {}, nextAction: {})
}
