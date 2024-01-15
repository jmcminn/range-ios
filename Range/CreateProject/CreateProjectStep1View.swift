@_spi(Experimental) import MapboxMaps
import SwiftUI

struct CreateProjectStep1View: View {
    @State var viewport: Viewport = .followPuck(zoom: 16)
    @ObservedObject var model: CreateProjectViewModel
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
        }
        .mapStyle(mapStyle)
        .onCameraChanged(action: { camera in
            model.cameraLocation = camera.cameraState.center
        })
        .ornamentOptions(.init(compass: .init(margins: CGPoint(x: 8, y: 102))))
        .ignoresSafeArea()
        .onReceive(model.$location) { location in
            guard let location else { return }
            withViewportAnimation(.easeIn(duration: 0.5)) {
                viewport = .camera(center: location)
            }
        }
    }

    private var placeAutocompletesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.placeAutocompletes, id: \.name) { place in
                        Button(action: { model.selectPlaceAutocomplete(place) }) {
                            HStack(alignment: .center, spacing: 9) {
                                Image("projects_icon")
                                    .renderingMode(.template)
                                    .foregroundColor(.dynamic(.Neutral_05))
                                VStack(alignment: .leading) {
                                    Text(place.text).font(.body).foregroundColor(.dynamic(.Neutral_04))
                                    Text(place.description).font(.subheadline).foregroundColor(.dynamic(.Neutral_05))
                                }
                                .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(16)
                            .background(placeAutocompleteBackground)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dynamic(.Neutral_10))
    }

    /// background for toolbar buttons
    private var placeAutocompleteBackground: some View {
        let rectangle = RoundedRectangle(cornerRadius: 12)
        // cannot add fill and stroke to rectangle, so we need rectange with background rectangle
        return rectangle
            .stroke(Color.dynamic(.Neutral_07), lineWidth: 1)
            .background(rectangle.fill(Color.dynamic(.Neutral_09)))
    }

    private var topBar: some View {
        VStack(spacing: 16) {
            if !model.addressAutocompleteMode {
                Text("Step 1: ").foregroundColor(.dynamic(.Neutral_05)) +
                    Text("Set Project Location").foregroundColor(.dynamic(.Neutral_04))
            }

            HStack(spacing: 10) {
                RepresentedSearchView(text: $model.address, onActivated: model.enableAddressAutocompleteMode)
                    .placeholder("Search for, or select a location...")
                    .frame(height: 48)

                if model.addressAutocompleteMode {
                    Button("Cancel", action: model.cancelAddressAutocompleteMode)
                        .font(.body)
                        .foregroundColor(.Primary_Blue_04)
                }
            }
        }
        .font(.subheadline.bold())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Color.dynamic(.Neutral_10))
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button("Cancel", action: cancelAction)
                .buttonStyle(._gray)
            Button("Next", action: nextAction)
                .buttonStyle(._blue)
                .disabled(model.location == nil || model.address.isEmpty)
        }
        .padding(16)
        .background(Color.dynamic(.Neutral_10))
    }

    var body: some View {
        ZStack {
            mapView
                .overlay {
                    Image("project_location_pin").offset(y: -36).allowsHitTesting(false)
                }

            VStack(spacing: 0) {
                topBar
                Divider().frame(height: 1).background(Color.dynamic(.Neutral_07))
                if model.addressAutocompleteMode {
                    placeAutocompletesView
                } else {
                    Spacer()
                    Divider().frame(height: 1).background(Color.dynamic(.Neutral_07))
                    bottomBar
                }
            }
            .animation(.default, value: model.addressAutocompleteMode)
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    CreateProjectStep1View(model: CreateProjectViewModel(), cancelAction: {}, nextAction: {})
}

#Preview("with address") {
    let model = CreateProjectViewModel()
    model.address = "25 Harstene Drive, Redwood City"
    return CreateProjectStep1View(model: model, cancelAction: {}, nextAction: {})
}

#Preview("address autocompletes") {
    let model = CreateProjectViewModel()
    model.address = "225 H"
    model.enableAddressAutocompleteMode()
    model.placeAutocompletes = [
        PlaceAutocomplete(id: "1", center: .init(), name: "Redwood City, CA 94065", text: "225 Harstene Drive"),
        PlaceAutocomplete(id: "2", center: .init(), name: "Redwood City, CA 94065", text: "225 Harstene Drive 2"),
        PlaceAutocomplete(
            id: "3",
            center: .init(),
            name: "Redwood City, CA 94065 CA Very very Long text ",
            text: "225 Harstene Drive 3"
        ),
    ]
    return CreateProjectStep1View(model: model, cancelAction: {}, nextAction: {})
}
