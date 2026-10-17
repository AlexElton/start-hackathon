import MapKit
import SharedModels
import SwiftUI

/// A map camera: centre, distance (m), pitch (0 = straight down) and heading (0 = north up).
struct CameraSpec {
    var center: CLLocationCoordinate2D
    var distance: Double
    var pitch: Double
    var heading: Double = 0

    var mkCamera: MKMapCamera {
        MKMapCamera(lookingAtCenter: center, fromDistance: distance, pitch: pitch, heading: heading)
    }

    /// False for NaN or out-of-range values, which MapKit throws on ("Invalid camera centerCoordinate nan, nan").
    var isValid: Bool {
        CLLocationCoordinate2DIsValid(center) && distance.isFinite && distance > 0 && pitch.isFinite && heading.isFinite
    }

    var mapCamera: MapCamera {
        MapCamera(centerCoordinate: center, distance: distance, heading: heading, pitch: pitch)
    }
}

/// A camera move the map should make once. A new `id` triggers it. `duration` 0 jumps.
struct CameraCommand: Identifiable {
    let id = UUID()
    let camera: CameraSpec
    var duration: Double = 0
    /// Cinematic dive: the target glides to the middle of the screen while the camera drops straight onto it.
    var cinematic = false
}

/// The cameras the intros move between (PLAN.md, "Intro animations").
enum IntroCameras {
    /// All of Norway, like the onboarding map. Start of the first intro when we don't know where step 3 ended,
    /// and of a replay from Innstillinger.
    /// Also the onboarding map's starting camera: centred a little north so Norway sits below the title.
    static let norway = CameraSpec(center: CLLocationCoordinate2D(latitude: 66.2, longitude: 17.6 + ZoomScale.globeLongitudeNudge), distance: 6_800_000, pitch: 0)

    /// Above the target at 3,000 km. Start of the fast intro on later launches.
    static func europe(over target: CameraSpec) -> CameraSpec {
        CameraSpec(center: target.center, distance: 3_000_000, pitch: 0)
    }

    /// The hand-picked Trondheim camera.
    static let trondheim = CameraSpec(
        center: CLLocationCoordinate2D(latitude: MapViewModel.startCenter.lat, longitude: MapViewModel.startCenter.lon),
        distance: MapViewModel.startDistance,
        pitch: MapViewModel.startPitch,
        heading: MapViewModel.startHeading
    )

    /// Where every intro ends: the user's position, the regional paper's city, or Trondheim.
    static func target(settings: SettingsStore, papers: [Paper], regions: [RegionShape], location: LocationService) -> CameraSpec {
        if settings.startMode == .position, let position = location.lastCoordinate {
            return CameraSpec(center: position, distance: trondheim.distance, pitch: trondheim.pitch)
        }
        return target(regionId: settings.regionId, papers: papers, regions: regions)
    }

    /// Where the intro ends for a fylke: its regional paper's city, the middle of the fylke, or Trondheim.
    static func target(regionId: String?, papers: [Paper], regions: [RegionShape]) -> CameraSpec {
        guard let regionId, regionId != "trondelag" else { return trondheim }
        if let paper = papers.first(where: { $0.regionId == regionId && $0.level == .regional }) {
            return CameraSpec(center: CLLocationCoordinate2D(latitude: paper.location.lat, longitude: paper.location.lon), distance: trondheim.distance, pitch: trondheim.pitch)
        }
        if let region = regions.first(where: { $0.id == regionId }) {
            return CameraSpec(center: region.label, distance: 80_000, pitch: 20) // A fylke without a Polaris paper.
        }
        return trondheim
    }
}

extension MKMapCamera {
    var isValid: Bool {
        CLLocationCoordinate2DIsValid(centerCoordinate) && centerCoordinateDistance.isFinite && centerCoordinateDistance > 0
            && pitch.isFinite && heading.isFinite
    }
}

extension MKMapView {
    /// Sets the camera, but drops one with NaN in it instead of crashing. A map that hasn't been laid out yet
    /// (zero size) reports NaN, and any math built on that carries it along.
    func setCameraSafely(_ camera: MKMapCamera) {
        guard camera.isValid else { return }
        self.camera = camera
    }
}
