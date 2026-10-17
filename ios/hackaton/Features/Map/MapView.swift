import MapKit
import SharedModels
import SwiftUI

/// `MKMapView` wrapper. UIKit instead of SwiftUI `Map` because we need MapKit clustering with custom cluster views.
/// Keep the map out of SwiftUI's re-render path: `updateUIView` only pushes changes.
struct MapView: UIViewRepresentable {
    var style: MapStyle
    /// The camera the map starts with (used once, when the map is created).
    var initialCamera: CameraSpec
    /// A one-off camera move, e.g. the fast intro. Applied when its id changes.
    var cameraCommand: CameraCommand?
    var items: [FeedItem]
    var zoomFraction: Double
    var isSliderActive: Bool
    var images: ImageLoader
    var onZoomChange: (Double) -> Void
    var onRegionChange: (FeedFilter.BoundingBox) -> Void
    /// A pin (one item) or a bunch (newest first) was tapped.
    var onSelect: ([FeedItem]) -> Void
    /// The map has drawn its first full frame.
    var onRendered: () -> Void = {}

    func makeUIView(context: Context) -> MKMapView {
        let mapView = FramingMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.preferredConfiguration = style.configuration
        mapView.register(ItemAnnotationView.self, forAnnotationViewWithReuseIdentifier: ItemAnnotationView.reuseIdentifier)
        mapView.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: ZoomScale.minDistance,
            maxCenterCoordinateDistance: 12_000_000 // Room for the intros to start from all of Norway.
        )
        // Set the start camera once the map has its real size, and again after MapKit's first layout pass:
        // set at zero size it opened at the wrong height on the 3D globe.
        let start = initialCamera
        mapView.onFirstLayout = { map in
            map.camera = start.mkCamera
            DispatchQueue.main.async { [weak map] in map?.camera = start.mkCamera }
        }
        context.coordinator.holdStartCamera(start)
        context.coordinator.mapView = mapView
        context.coordinator.currentStyle = style
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.currentStyle != style {
            mapView.preferredConfiguration = style.configuration
            coordinator.currentStyle = style
        }
        coordinator.apply(items)
        if let command = cameraCommand, command.id != coordinator.lastCommandId {
            coordinator.lastCommandId = command.id
            if command.duration > 0 {
                coordinator.fly(to: command.camera, duration: command.duration, cinematic: command.cinematic)
            } else {
                mapView.camera = command.camera.mkCamera
            }
        }
        if isSliderActive {
            coordinator.zoom(toFraction: zoomFraction)
        }
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        coordinator.stopZoomAnimation()
        coordinator.stopFlight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        weak var mapView: MKMapView?
        var currentStyle: MapStyle?
        var lastCommandId: UUID?
        private var annotations: [String: ItemAnnotation] = [:]
        private var displayLink: CADisplayLink?
        private var targetDistance: Double?
        /// Where the user was before zooming out to the Norway overview, so zooming back in returns there.
        private var localCenter: CLLocationCoordinate2D?

        init(parent: MapView) {
            self.parent = parent
        }

        // MARK: Pins

        /// Adds and removes only what changed, by id. Never removes everything and re-adds it.
        func apply(_ items: [FeedItem]) {
            guard let mapView else { return }
            var next: [String: ItemAnnotation] = [:]
            var added: [ItemAnnotation] = []
            for item in items {
                if let existing = annotations[item.id], existing.item == item {
                    next[item.id] = existing
                } else {
                    let annotation = ItemAnnotation(item: item)
                    next[item.id] = annotation
                    added.append(annotation)
                }
            }
            let removed = annotations.compactMap { id, annotation in next[id] === annotation ? nil : annotation }
            guard !added.isEmpty || !removed.isEmpty else { return }
            annotations = next
            mapView.removeAnnotations(removed)
            mapView.addAnnotations(added)
        }

        private var hasRendered = false

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            guard fullyRendered, !hasRendered else { return } // Not before the tiles are actually drawn.
            hasRendered = true
            parent.onRendered()
        }

        /// Opens a pin or bunch on touch-up. MapKit's own selection waits ~0.3 s to rule out a double-tap.
        @objc func pinTapped(_ gesture: UITapGestureRecognizer) {
            switch (gesture.view as? MKAnnotationView)?.annotation {
            case let annotation as ItemAnnotation:
                parent.onSelect([annotation.item])
            case let cluster as MKClusterAnnotation:
                parent.onSelect(ClusterAnnotationView.sortedItems(in: cluster))
            default:
                break
            }
        }

        private func addTapIfNeeded(to view: MKAnnotationView?) {
            guard let view, !(view.gestureRecognizers ?? []).contains(where: { $0.name == "pinTap" }) else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(pinTapped(_:)))
            tap.name = "pinTap"
            view.addGestureRecognizer(tap)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let annotation as ItemAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: ItemAnnotationView.reuseIdentifier, for: annotation) as? ItemAnnotationView
                view?.images = parent.images
                view?.refresh()
                addTapIfNeeded(to: view)
                return view
            case let cluster as MKClusterAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: cluster) as? ClusterAnnotationView
                view?.images = parent.images
                view?.refresh()
                addTapIfNeeded(to: view)
                return view
            default:
                return nil // Blue dot stays default.
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            guard !(annotation is MKUserLocation) else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            switch annotation {
            case let annotation as ItemAnnotation:
                parent.onSelect([annotation.item])
            case let cluster as MKClusterAnnotation:
                parent.onSelect(ClusterAnnotationView.sortedItems(in: cluster))
            default:
                break
            }
        }

        // MARK: Flight (intros)

        private var flight: CameraFlight?

        func fly(to target: CameraSpec, duration: Double, cinematic: Bool = false) {
            guard let mapView else { return }
            startCamera = nil // A flight takes over the camera.
            flight?.stop()
            flight = CameraFlight(mapView: mapView, to: target, duration: duration, cinematic: cinematic)
        }

        func stopFlight() {
            flight?.stop()
            flight = nil
        }

        // MARK: Region and zoom

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            // Pinch and scroll update the slider, but not while the slider itself drives the camera.
            guard displayLink == nil, !parent.isSliderActive else { return }
            parent.onZoomChange(ZoomScale.fraction(for: mapView.camera.centerCoordinateDistance))
        }

        /// MapKit applies its own default view (the whole country) shortly after the map appears, which
        /// overrode our start camera when no intro moved it afterwards. For a short while, put it back.
        private var startCamera: CameraSpec?
        private var startCameraUntil: CFTimeInterval = 0

        func holdStartCamera(_ camera: CameraSpec) {
            startCamera = camera
            startCameraUntil = CACurrentMediaTime() + 1.5
        }

        private func restoreStartCameraIfOverridden(_ mapView: MKMapView) {
            guard let start = startCamera else { return }
            guard CACurrentMediaTime() < startCameraUntil, flight == nil, displayLink == nil,
                  !mapView.isUserInteracting else {
                startCamera = nil
                return
            }
            if abs(log(mapView.camera.centerCoordinateDistance / start.distance)) > 0.1 {
                mapView.camera = start.mkCamera
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            restoreStartCameraIfOverridden(mapView)
            if mapView.camera.centerCoordinateDistance <= ZoomScale.overviewStartDistance {
                localCenter = mapView.camera.centerCoordinate
            }
            let region = mapView.region
            parent.onRegionChange(FeedFilter.BoundingBox(
                minLat: region.center.latitude - region.span.latitudeDelta / 2,
                minLon: region.center.longitude - region.span.longitudeDelta / 2,
                maxLat: region.center.latitude + region.span.latitudeDelta / 2,
                maxLon: region.center.longitude + region.span.longitudeDelta / 2
            ))
        }

        /// The slider sets a target; a display link eases the camera towards it every frame.
        func zoom(toFraction fraction: Double) {
            targetDistance = ZoomScale.distance(for: fraction)
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(stepZoom))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopZoomAnimation() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func stepZoom() {
            guard let mapView, let targetDistance else { return stopZoomAnimation() }
            let current = mapView.camera.centerCoordinateDistance
            // Ease in log space, so a step feels the same size near and far.
            let logCurrent = log(current)
            let logTarget = log(targetDistance)
            guard abs(logTarget - logCurrent) > 0.002 else {
                // Arrived. Keep the link alive while the finger is still on the slider.
                if !parent.isSliderActive {
                    stopZoomAnimation()
                    self.targetDistance = nil
                }
                return
            }
            let camera = mapView.camera.copy() as! MKMapCamera
            let next = exp(logCurrent + (logTarget - logCurrent) * 0.2)
            camera.centerCoordinateDistance = next
            // Zooming out far, glide from where the user was towards the middle of Norway so the whole country
            // fits. Zooming back in goes straight into whatever is in the middle of the screen.
            if let local = localCenter, next > current, next > ZoomScale.overviewStartDistance {
                let weight = ZoomScale.overviewWeight(for: next)
                camera.centerCoordinate = CLLocationCoordinate2D(
                    latitude: local.latitude + (ZoomScale.norwayCenter.latitude - local.latitude) * weight,
                    longitude: local.longitude + (ZoomScale.norwayCenter.longitude - local.longitude) * weight
                )
            }
            mapView.camera = camera
        }
    }
}

extension MapStyle {
    /// The MapKit configuration for this style; shared by the main map and the onboarding map.
    var configuration: MKMapConfiguration {
        switch self {
        case .standard: MKStandardMapConfiguration(elevationStyle: .realistic)
        case .hybrid: MKHybridMapConfiguration(elevationStyle: .realistic)
        case .satellite: MKImageryMapConfiguration(elevationStyle: .realistic)
        }
    }
}

private extension MKMapView {
    /// True while a finger is panning, pinching or rotating the map.
    var isUserInteracting: Bool {
        (subviews.first?.gestureRecognizers ?? []).contains { $0.state == .began || $0.state == .changed }
    }
}
