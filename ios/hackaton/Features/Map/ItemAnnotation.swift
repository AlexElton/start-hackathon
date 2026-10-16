import MapKit
import SharedModels

/// One feed item on the map.
final class ItemAnnotation: NSObject, MKAnnotation {
    let item: FeedItem

    init(item: FeedItem) {
        self.item = item
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: item.location?.lat ?? 0, longitude: item.location?.lon ?? 0)
    }

    var title: String? { item.title }
}
