import Foundation

/// The `/feed` query parameters, typed. The app builds `queryItems`; the backend parses them with `init(query:)`.
public struct FeedFilter: Hashable, Sendable {
    public enum When: String, Sendable, CaseIterable {
        /// Events starting today after 16:00, plus deals valid today.
        case tonight
        case today
        case week
    }

    public enum Sort: String, Sendable, CaseIterable {
        case time
        case distance
        case relevance
    }

    public struct BoundingBox: Hashable, Sendable {
        public var minLat: Double
        public var minLon: Double
        public var maxLat: Double
        public var maxLon: Double

        public init(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
            self.minLat = minLat
            self.minLon = minLon
            self.maxLat = maxLat
            self.maxLon = maxLon
        }

        public func contains(_ point: GeoPoint) -> Bool {
            (minLat...maxLat).contains(point.lat) && (minLon...maxLon).contains(point.lon)
        }
    }

    public static let defaultLimit = 200
    public static let maxLimit = 500

    public var kinds: Set<ItemKind>?
    public var categories: Set<String>?
    public var exclude: Set<String>
    public var mute: [String]
    public var bbox: BoundingBox?
    public var near: GeoPoint?
    public var radiusKm: Double?
    public var paper: String?
    public var when: When?
    public var sort: Sort
    public var prefer: Set<String>
    public var limit: Int

    public init(
        kinds: Set<ItemKind>? = nil,
        categories: Set<String>? = nil,
        exclude: Set<String> = [],
        mute: [String] = [],
        bbox: BoundingBox? = nil,
        near: GeoPoint? = nil,
        radiusKm: Double? = nil,
        paper: String? = nil,
        when: When? = nil,
        sort: Sort = .time,
        prefer: Set<String> = [],
        limit: Int = FeedFilter.defaultLimit
    ) {
        self.kinds = kinds
        self.categories = categories
        self.exclude = exclude
        self.mute = mute
        self.bbox = bbox
        self.near = near
        self.radiusKm = radiusKm
        self.paper = paper
        self.when = when
        self.sort = sort
        self.prefer = prefer
        self.limit = limit
    }

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case invalid(String, String)

        public var description: String {
            switch self {
            case let .invalid(name, value): "invalid value '\(value)' for '\(name)'"
            }
        }
    }

    /// Parses raw query parameters. Lists are comma-separated; unknown params are ignored.
    public init(query: [String: String]) throws(ParseError) {
        func list(_ name: String) -> [String]? {
            guard let raw = query[name] else { return nil }
            let values = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return values.isEmpty ? nil : values
        }
        func doubles(_ name: String, count: Int) throws(ParseError) -> [Double]? {
            guard let values = list(name) else { return nil }
            let numbers = values.compactMap(Double.init)
            guard numbers.count == count, numbers.count == values.count else {
                throw .invalid(name, query[name] ?? "")
            }
            return numbers
        }

        self.init()

        if let values = list("kinds") {
            var kinds = Set<ItemKind>()
            for value in values {
                guard let kind = ItemKind(rawValue: value) else { throw .invalid("kinds", value) }
                kinds.insert(kind)
            }
            self.kinds = kinds
        }
        categories = list("categories").map(Set.init)
        exclude = Set(list("exclude") ?? [])
        mute = (list("mute") ?? []).map { $0.lowercased() }
        prefer = Set(list("prefer") ?? [])
        paper = query["paper"].flatMap { $0.isEmpty ? nil : $0 }

        if let box = try doubles("bbox", count: 4) {
            guard box[0] <= box[2], box[1] <= box[3] else { throw .invalid("bbox", query["bbox"] ?? "") }
            bbox = BoundingBox(minLat: box[0], minLon: box[1], maxLat: box[2], maxLon: box[3])
        }
        if let point = try doubles("near", count: 2) {
            near = GeoPoint(lat: point[0], lon: point[1])
        }
        if let raw = query["radiusKm"] {
            guard let radius = Double(raw), radius > 0 else { throw .invalid("radiusKm", raw) }
            radiusKm = radius
        }
        if let raw = query["when"] {
            guard let value = When(rawValue: raw) else { throw .invalid("when", raw) }
            when = value
        }
        if let raw = query["sort"] {
            guard let value = Sort(rawValue: raw) else { throw .invalid("sort", raw) }
            sort = value
        }
        if sort == .distance, near == nil {
            throw .invalid("sort", "distance needs near")
        }
        if let raw = query["limit"] {
            guard let value = Int(raw), value > 0 else { throw .invalid("limit", raw) }
            limit = min(value, Self.maxLimit)
        }
    }

    /// Query items for building a `/feed` URL. Only non-default values are included.
    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ values: some Sequence<String>) {
            let joined = values.sorted().joined(separator: ",")
            if !joined.isEmpty { items.append(URLQueryItem(name: name, value: joined)) }
        }
        if let kinds { add("kinds", kinds.map(\.rawValue)) }
        if let categories { add("categories", categories) }
        add("exclude", exclude)
        add("mute", mute)
        if let bbox {
            items.append(URLQueryItem(name: "bbox", value: "\(bbox.minLat),\(bbox.minLon),\(bbox.maxLat),\(bbox.maxLon)"))
        }
        if let near { items.append(URLQueryItem(name: "near", value: "\(near.lat),\(near.lon)")) }
        if let radiusKm { items.append(URLQueryItem(name: "radiusKm", value: "\(radiusKm)")) }
        if let paper { items.append(URLQueryItem(name: "paper", value: paper)) }
        if let when { items.append(URLQueryItem(name: "when", value: when.rawValue)) }
        if sort != .time { items.append(URLQueryItem(name: "sort", value: sort.rawValue)) }
        add("prefer", prefer)
        if limit != Self.defaultLimit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        return items
    }
}
