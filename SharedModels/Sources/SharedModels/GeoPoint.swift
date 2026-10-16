import Foundation

/// A plain lat/lon pair. Kept free of CoreLocation so the backend can use it on Linux.
public struct GeoPoint: Codable, Hashable, Sendable {
    public var lat: Double
    public var lon: Double
    public var name: String?

    public init(lat: Double, lon: Double, name: String? = nil) {
        self.lat = lat
        self.lon = lon
        self.name = name
    }

    /// Great-circle distance in kilometres (haversine).
    public func distanceKm(to other: GeoPoint) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (other.lat - lat) * .pi / 180
        let dLon = (other.lon - lon) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat * .pi / 180) * cos(other.lat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
