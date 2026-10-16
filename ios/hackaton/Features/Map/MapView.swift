import MapKit
import SwiftUI

/// `MKMapView` wrapper. UIKit instead of SwiftUI `Map` because we need custom clustering later.
/// Keep the map out of SwiftUI's re-render path: `updateUIView` only pushes changes.
struct MapView: UIViewRepresentable {
    var style: MapStyle

    static let trondheim = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.preferredConfiguration = style.configuration
        mapView.camera = MKMapCamera(
            lookingAtCenter: Self.trondheim,
            fromDistance: 3_500,
            pitch: 58,
            heading: 0
        )
        context.coordinator.currentStyle = style
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if context.coordinator.currentStyle != style {
            mapView.preferredConfiguration = style.configuration
            context.coordinator.currentStyle = style
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentStyle: MapStyle?
    }
}

private extension MapStyle {
    var configuration: MKMapConfiguration {
        switch self {
        case .standard: MKStandardMapConfiguration(elevationStyle: .realistic)
        case .hybrid: MKHybridMapConfiguration(elevationStyle: .realistic)
        case .satellite: MKImageryMapConfiguration(elevationStyle: .realistic)
        }
    }
}
