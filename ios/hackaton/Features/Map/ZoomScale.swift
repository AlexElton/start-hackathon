import Foundation

import CoreLocation

/// Maps the zoom slider (0 = closest, 1 = furthest) to camera distance on a log scale:
/// distance = 1 km × 5500^t. Equal slider steps feel equally big at every zoom level,
/// so far out it moves fast and close in it moves gently.
enum ZoomScale {
    static let minDistance: Double = 1_000
    /// Furthest out: all of mainland Norway (58–71° N, 4.6–31° E) fits a portrait phone when centred on `norwayCenter`.
    static let maxDistance: Double = 5_500_000

    /// Beyond this distance the slider glides the view towards the middle of Norway, so the whole country fits.
    static let overviewStartDistance: Double = 800_000
    static let norwayCenter = CLLocationCoordinate2D(latitude: 64.6, longitude: 17.9 + globeLongitudeNudge)

    /// On a real phone MapKit draws the map this far out as a 3D globe, which shows Norway a few degrees left
    /// of where the flat simulator does. Aiming the camera this much further west puts it back in the middle.
    static var globeLongitudeNudge: Double {
        #if targetEnvironment(simulator)
        0
        #else
        -3
        #endif
    }

    /// 0 at `overviewStartDistance` and closer, 1 at `maxDistance`, on the same log scale as the slider.
    static func overviewWeight(for distance: Double) -> Double {
        guard distance > overviewStartDistance else { return 0 }
        return (log(distance / overviewStartDistance) / log(maxDistance / overviewStartDistance)).clamped(to: 0...1)
    }

    static func distance(for fraction: Double) -> Double {
        minDistance * pow(maxDistance / minDistance, fraction.clamped(to: 0...1))
    }

    static func fraction(for distance: Double) -> Double {
        (log(distance / minDistance) / log(maxDistance / minDistance)).clamped(to: 0...1)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
