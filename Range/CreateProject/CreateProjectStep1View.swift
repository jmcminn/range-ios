@_spi(Experimental) import MapboxMaps
import SwiftUI

struct CreateProjectStep1View: View {
    @State var viewport: Viewport = .followPuck(zoom: 16)
    @ObservedObject var model: CreateProjectViewModel
    let onMapTap: (CLLocationCoordinate2D) -> Void
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
        Map(viewport: $viewport) {
            puck2D

            if let location = model.location {
                MapViewAnnotation(coordinate: location) {
                    Image("project_location_pin")
                }
                .selected(true)
                .variableAnchors([
                    ViewAnnotationAnchorConfig(anchor: .center, offsetY: 29),
                ])
                .allowOverlap(true)
                .allowOverlapWithPuck(true)
            }
        }
        .mapStyle(mapStyle)
        .onMapTapGesture { context in
            onMapTap(context.coordinate)
            withViewportAnimation(.easeIn(duration: 0.5)) {
                viewport = .camera(center: context.coordinate)
            }
        }
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
                    .disabled(model.location == nil)
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
        .navigationBarHidden(true)
    }
}

#Preview {
    CreateProjectStep1View(model: CreateProjectViewModel(), onMapTap: { _ in }, cancelAction: {}, nextAction: {})
}

#Preview("with address") {
    let model = CreateProjectViewModel()
    model.address = "25 Harstene Drive, Redwood City"
    return CreateProjectStep1View(model: model, onMapTap: { _ in }, cancelAction: {}, nextAction: {})
}
