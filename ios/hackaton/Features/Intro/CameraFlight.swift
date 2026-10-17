import MapKit
import SwiftUI

/// Flies an `MKMapView`'s camera to a target in exactly `duration` seconds, one frame at a time (up to 120 Hz).
/// Used by the main map's intros and by the onboarding map's dive after "Kom i gang".
final class CameraFlight {
    private weak var mapView: MKMapView?
    private let from: MKMapCamera
    private let to: CameraSpec
    private let start = CACurrentMediaTime()
    private let duration: Double
    private let cinematic: Bool
    private let completion: () -> Void
    private var link: CADisplayLink?

    /// Soft start (no jolt when the app opens), then a long deceleration towards the ground.
    private static let flightCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.42, y: 0), endControlPoint: UnitPoint(x: 0.12, y: 1))
    /// Gentle lift-off, steady middle, very long settle: reads as one continuous camera move.
    private static let cinematicCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.4, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1))

    init(mapView: MKMapView, to target: CameraSpec, duration: Double, cinematic: Bool, completion: @escaping () -> Void = {}) {
        self.mapView = mapView
        from = mapView.camera.copy() as! MKMapCamera
        to = target
        self.duration = duration
        self.cinematic = cinematic
        self.completion = completion
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120) // ProMotion
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step() {
        guard let mapView else { return stop() }
        let t = duration > 0 ? min((CACurrentMediaTime() - start) / duration, 1) : 1
        // Started on a map without a usable camera (not laid out yet): just land on the target.
        guard from.isValid, t < 1 else {
            mapView.setCameraSafely(to.mkCamera)
            stop()
            completion()
            return
        }
        let logFrom = log(from.centerCoordinateDistance)
        let logTo = log(to.distance)
        let center: CLLocationCoordinate2D
        let distance: Double
        let tilt: Double

        if cinematic {
            // Dive straight down onto the target: the distance shrinks on a log scale with a slow start and a long,
            // soft landing, and the target slides from where it sits on screen to the middle at an even pace.
            // Keeping the map offset proportional to the height means nothing swerves sideways.
            let progress = Self.cinematicCurve.value(at: t)
            distance = exp(logFrom + (logTo - logFrom) * progress)
            let glide = t * t * (3 - 2 * t)
            let scale = distance / from.centerCoordinateDistance * (1 - glide)
            center = CLLocationCoordinate2D(
                latitude: to.center.latitude + (from.centerCoordinate.latitude - to.center.latitude) * scale,
                longitude: to.center.longitude + (from.centerCoordinate.longitude - to.center.longitude) * scale
            )
            let tiltProgress = max(0, (t - 0.62) / 0.38)
            tilt = tiltProgress * tiltProgress * (3 - 2 * tiltProgress)
        } else {
            let progress = Self.flightCurve.value(at: t)
            distance = exp(logFrom + (logTo - logFrom) * progress)
            center = CLLocationCoordinate2D(
                latitude: from.centerCoordinate.latitude + (to.center.latitude - from.centerCoordinate.latitude) * progress,
                longitude: from.centerCoordinate.longitude + (to.center.longitude - from.centerCoordinate.longitude) * progress
            )
            let tiltProgress = max(0, (t - 0.55) / 0.45)
            tilt = tiltProgress * tiltProgress * (3 - 2 * tiltProgress)
        }

        mapView.setCameraSafely(MKMapCamera(
            lookingAtCenter: center,
            fromDistance: distance,
            pitch: from.pitch + (to.pitch - from.pitch) * tilt,
            heading: to.heading
        ))
    }
}
