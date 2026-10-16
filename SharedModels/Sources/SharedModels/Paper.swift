/// A Polaris newspaper (avis). `regionId` links it to a zone in `/regions`.
public struct Paper: Codable, Identifiable, Hashable, Sendable {
    public enum Level: String, Codable, Sendable {
        case regional
        case local
    }

    public var id: String
    public var name: String
    public var city: String
    public var location: GeoPoint
    public var logoUrl: String?
    public var color: String
    public var regionId: String
    public var level: Level

    public init(
        id: String,
        name: String,
        city: String,
        location: GeoPoint,
        logoUrl: String? = nil,
        color: String,
        regionId: String,
        level: Level
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.location = location
        self.logoUrl = logoUrl
        self.color = color
        self.regionId = regionId
        self.level = level
    }
}
