import MapKit
import SharedModels
import SwiftUI

/// `MKMapView` wrapper. UIKit instead of SwiftUI `Map` because we need MapKit clustering with custom cluster views.
/// Keep the map out of SwiftUI's re-render path: `updateUIView` only pushes changes.
struct MapView: UIViewRepresentable {
    var style: MapStyle
    var items: [FeedItem]
    var zoomFraction: Double
    var isSliderActive: Bool
    var images: ImageLoader
    var onZoomChange: (Double) -> Void
    var onRegionChange: (FeedFilter.BoundingBox) -> Void
    /// A pin (one item) or a bunch (newest first) was tapped.
    var onSelect: ([FeedItem]) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.preferredConfiguration = style.configuration
        mapView.register(ItemAnnotationView.self, forAnnotationViewWithReuseIdentifier: ItemAnnotationView.reuseIdentifier)
        mapView.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: ZoomScale.minDistance,
            maxCenterCoordinateDistance: ZoomScale.maxDistance
        )
        mapView.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: MapViewModel.startCenter.lat, longitude: MapViewModel.startCenter.lon),
            fromDistance: MapViewModel.startDistance,
            pitch: MapViewModel.startPitch,
            heading: MapViewModel.startHeading
        )
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
        if isSliderActive {
            coordinator.zoom(toFraction: zoomFraction)
        }
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        coordinator.stopZoomAnimation()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        weak var mapView: MKMapView?
        var currentStyle: MapStyle?
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

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let annotation as ItemAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: ItemAnnotationView.reuseIdentifier, for: annotation) as? ItemAnnotationView
                view?.images = parent.images
                view?.refresh()
                return view
            case let cluster as MKClusterAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: cluster) as? ClusterAnnotationView
                view?.images = parent.images
                view?.refresh()
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

        // MARK: Region and zoom

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            // Pinch and scroll update the slider, but not while the slider itself drives the camera.
            guard displayLink == nil, !parent.isSliderActive else { return }
            parent.onZoomChange(ZoomScale.fraction(for: mapView.camera.centerCoordinateDistance))
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
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
            // Far out, blend from where the user was towards the middle of Norway so the whole country fits;
            // on the way back in the blend reverses and lands where they started.
            if let local = localCenter, max(current, next) > ZoomScale.overviewStartDistance {
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

private extension MapStyle {
    var configuration: MKMapConfiguration {
        switch self {
        case .standard: MKStandardMapConfiguration(elevationStyle: .realistic)
        case .hybrid: MKHybridMapConfiguration(elevationStyle: .realistic)
        case .satellite: MKImageryMapConfiguration(elevationStyle: .realistic)
        }
    }
}
