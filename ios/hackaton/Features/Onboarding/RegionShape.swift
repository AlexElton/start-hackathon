import MapKit
import SwiftUI

/// One fylke from `regions.geojson`: outline parts for drawing, a path for tap testing and a label point.
struct RegionShape: Identifiable {
    let id: String
    let name: String
    let regionalPaperId: String?
    /// Can be picked in onboarding (every fylke except Oslo).
    let selectable: Bool
    /// A shade of Adressablå; neighbours always differ.
    let color: Color?
    let label: CLLocationCoordinate2D
    let polygons: [MKPolygon]
    /// Outlines in `MKMapPoint` space, for `contains` on tap.
    let hitPath: CGPath


    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let point = MKMapPoint(coordinate)
        return hitPath.contains(CGPoint(x: point.x, y: point.y), using: .evenOdd)
    }

    private struct Properties: Decodable {
        struct Point: Decodable { let lat: Double; let lon: Double }
        let id: String
        let name: String
        let regionalPaperId: String?
        let selectable: Bool?
        let color: String?
        let labelPoint: Point
    }

    /// Decodes the GeoJSON with `MKGeoJSONDecoder` (multipolygons become `MKMultiPolygon`).
    static func parse(_ data: Data) throws -> [RegionShape] {
        try MKGeoJSONDecoder().decode(data).compactMap { object -> RegionShape? in
            guard let feature = object as? MKGeoJSONFeature, let raw = feature.properties else { return nil }
            let properties = try JSONDecoder().decode(Properties.self, from: raw)
            let polygons = feature.geometry.flatMap { geometry -> [MKPolygon] in
                if let multi = geometry as? MKMultiPolygon { return multi.polygons }
                if let polygon = geometry as? MKPolygon { return [polygon] }
                return []
            }
            let path = CGMutablePath()
            for polygon in polygons {
                for ring in [polygon] + (polygon.interiorPolygons ?? []) {
                    let points = UnsafeBufferPointer(start: ring.points(), count: ring.pointCount).map { CGPoint(x: $0.x, y: $0.y) }
                    path.addLines(between: points)
                    path.closeSubpath()
                }
            }
            return RegionShape(
                id: properties.id,
                name: properties.name,
                regionalPaperId: properties.regionalPaperId,
                selectable: properties.selectable ?? (properties.regionalPaperId != nil),
                color: properties.color.map { Color(hex: $0) },
                label: CLLocationCoordinate2D(latitude: properties.labelPoint.lat, longitude: properties.labelPoint.lon),
                polygons: polygons,
                hitPath: path
            )
        }
    }
}
