import MapKit
import SharedModels
import SwiftUI

/// Step 3's map: an `MKMapView` in the same style as the main map, so the hand-off to it is seamless.
/// Everything outside Norway is white, and the fylker you can't pick are greyed out with diagonal hatching;
/// the fylker with a Polaris paper are solid blue and tappable
/// (the picked one darker), with a clean white line only where two of them meet. The rest is plain map.
/// UIKit instead of SwiftUI `Map`: a tap only recolours one shape instead of rebuilding the whole map.
struct RegionMapView: UIViewRepresentable {
    let regions: [RegionShape]
    let cover: MKPolygon?
    let borders: [MKPolyline]
    let style: MapStyle
    @Binding var selectedId: String?
    /// Reports where the camera is, so the first intro starts from the same view.
    @Binding var camera: CameraSpec?
    /// When true, the white cover and the fylker fade out, then `onFadedOut` runs.
    let isFadingOut: Bool
    let onFadedOut: () -> Void

    /// Mainland Norway, Lindesnes to Nordkapp (Svalbard left out).
    static let norwayRect: MKMapRect = {
        let southWest = MKMapPoint(CLLocationCoordinate2D(latitude: 57.8, longitude: 4.4))
        let northEast = MKMapPoint(CLLocationCoordinate2D(latitude: 71.3, longitude: 31.3))
        return MKMapRect(x: min(southWest.x, northEast.x), y: min(southWest.y, northEast.y), width: abs(northEast.x - southWest.x), height: abs(northEast.y - southWest.y))
    }()

    static let fill = UIColor(hex: "#5BA2CB")
    static let selectedFill = UIColor.adressaBlue

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = style.configuration
        // Norway framed between the title and the button.
        mapView.setVisibleMapRect(Self.norwayRect, edgePadding: UIEdgeInsets(top: 190, left: 24, bottom: 110, right: 24), animated: false)
        mapView.cameraBoundary = MKMapView.CameraBoundary(mapRect: Self.norwayRect.insetBy(dx: -Self.norwayRect.width * 0.3, dy: -Self.norwayRect.height * 0.3))
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 50_000, maxCenterCoordinateDistance: 12_000_000)
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false

        // Fires on touch-up: no waiting to see if it becomes a double-tap zoom.
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        mapView.addGestureRecognizer(tap)

        context.coordinator.mapView = mapView
        context.coordinator.install(regions: regions, cover: cover, borders: borders)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.regionCount != regions.count || (coordinator.cover == nil && cover != nil) {
            coordinator.install(regions: regions, cover: cover, borders: borders)
        }
        coordinator.highlight(selectedId)
        if isFadingOut { coordinator.fadeOut() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RegionMapView
        weak var mapView: MKMapView?
        private(set) var cover: MKPolygon?
        private(set) var regionCount = 0
        /// Fill overlay per selectable fylke, and the fylke for each overlay.
        private var fills: [String: MKMultiPolygon] = [:]
        private var regionByOverlay: [ObjectIdentifier: String] = [:]
        /// Parts of the fylker you can't pick, drawn hatched.
        private var hatched = Set<ObjectIdentifier>()
        private var borderLine: MKMultiPolyline?
        private var highlighted: String?
        private var fadeLink: CADisplayLink?
        private var fadeStart: CFTimeInterval = 0

        init(parent: RegionMapView) { self.parent = parent }

        func install(regions: [RegionShape], cover: MKPolygon?, borders: [MKPolyline]) {
            guard let mapView else { return }
            mapView.removeOverlays(mapView.overlays)
            self.cover = cover // Must be known before adding: MapKit may ask for its renderer right away.
            fills = [:]
            regionByOverlay = [:]
            hatched = []
            for region in regions {
                if region.selectable {
                    let overlay = MKMultiPolygon(region.polygons)
                    fills[region.id] = overlay
                    regionByOverlay[ObjectIdentifier(overlay)] = region.id
                    mapView.addOverlay(overlay, level: .aboveRoads)
                } else {
                    for part in region.polygons {
                        let overlay = MKPolygon(points: part.points(), count: part.pointCount)
                        hatched.insert(ObjectIdentifier(overlay))
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }
                }
            }
            if !borders.isEmpty {
                let line = MKMultiPolyline(borders)
                borderLine = line
                mapView.addOverlay(line, level: .aboveRoads)
            }
            if let cover {
                mapView.addOverlay(cover, level: .aboveLabels) // White over everything outside Norway, labels too.
            }
            regionCount = regions.count
            highlighted = nil
        }

        /// Recolours only the fylker whose state changed.
        func highlight(_ id: String?) {
            guard let mapView, id != highlighted else { return }
            for regionId in [highlighted, id].compactMap({ $0 }) {
                guard let overlay = fills[regionId], let renderer = mapView.renderer(for: overlay) as? MKMultiPolygonRenderer else { continue }
                renderer.fillColor = regionId == id ? RegionMapView.selectedFill : RegionMapView.fill
                renderer.setNeedsDisplay()
            }
            highlighted = id
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let mapView else { return }
            let coordinate = mapView.convert(gesture.location(in: mapView), toCoordinateFrom: mapView)
            guard let region = parent.regions.first(where: { $0.selectable && $0.contains(coordinate) }) else { return }
            parent.selectedId = region.id
            UISelectionFeedbackGenerator().selectionChanged()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if overlay === cover, let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = .white
                return renderer
            }
            if let polygon = overlay as? MKPolygon, hatched.contains(ObjectIdentifier(polygon)) {
                return HatchedPolygonRenderer(polygon: polygon)
            }
            if let line = overlay as? MKMultiPolyline {
                let renderer = MKMultiPolylineRenderer(multiPolyline: line)
                renderer.strokeColor = .white
                renderer.lineWidth = 1.5
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }
            if let polygon = overlay as? MKMultiPolygon {
                let renderer = MKMultiPolygonRenderer(multiPolygon: polygon)
                let id = regionByOverlay[ObjectIdentifier(polygon)]
                renderer.fillColor = id != nil && id == highlighted ? RegionMapView.selectedFill : RegionMapView.fill
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            reportCamera(mapView)
        }

        private func reportCamera(_ mapView: MKMapView) {
            let camera = mapView.camera
            parent.camera = CameraSpec(center: camera.centerCoordinate, distance: camera.centerCoordinateDistance, pitch: camera.pitch, heading: camera.heading)
        }

        /// Fades the white cover and the fylker out over 0.5 s, leaving the plain map: the same view the
        /// main map opens on.
        func fadeOut() {
            guard fadeLink == nil, let mapView, !mapView.overlays.isEmpty else { return }
            reportCamera(mapView) // The exact view the main map must open on.
            fadeStart = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(stepFade))
            link.add(to: .main, forMode: .common)
            fadeLink = link
        }

        @objc private func stepFade() {
            guard let mapView else { return }
            let t = min((CACurrentMediaTime() - fadeStart) / 0.5, 1)
            let alpha = 1 - t * t * (3 - 2 * t)
            for overlay in mapView.overlays {
                guard let renderer = mapView.renderer(for: overlay) else { continue }
                renderer.alpha = alpha
                renderer.setNeedsDisplay()
            }
            if t >= 1 {
                fadeLink?.invalidate()
                fadeLink = nil
                parent.onFadedOut()
            }
        }
    }
}

/// Grey fill with thin diagonal lines: the "not available" look for fylker you can't pick.
/// Lines keep the same on-screen spacing at every zoom, and line up across MapKit's tiles.
final class HatchedPolygonRenderer: MKPolygonRenderer {
    private let spacing: CGFloat = 9      // screen points between lines
    private let hatchWidth: CGFloat = 1   // screen points
    private let base = UIColor(hex: "#E4E4E1")
    private let hatch = UIColor(hex: "#C9C9C4")

    override init(polygon: MKPolygon) {
        super.init(polygon: polygon)
        fillColor = base
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        guard let path else { return }

        context.saveGState()
        context.addPath(path)
        context.clip(using: .evenOdd) // Keep the lines inside the shape (and out of any holes).

        let step = spacing / zoomScale
        let rect = self.rect(for: mapRect)
        context.setStrokeColor(hatch.cgColor)
        context.setLineWidth(hatchWidth / zoomScale)
        // 45° lines x - y = k·step, on a grid shared by all tiles.
        var k = floor((rect.minX - rect.maxY) / step)
        let end = rect.maxX - rect.minY
        while k * step <= end {
            let offset = k * step
            context.move(to: CGPoint(x: rect.minY + offset, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.maxY + offset, y: rect.maxY))
            k += 1
        }
        context.strokePath()
        context.restoreGState()
    }
}
