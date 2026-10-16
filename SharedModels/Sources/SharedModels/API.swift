import Foundation

/// Paths shared by the app and the backend, so the contract lives in one place.
public enum API {
    public static let basePath = "api/v1"

    public enum Path {
        public static let health = "health"
        public static let feed = "feed"
        public static let articles = "articles"
        public static let categories = "categories"
        public static let papers = "papers"
        public static let summarize = "summarize"
    }
}

public extension JSONDecoder {
    /// Decoder matching the API: ISO 8601 dates.
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    /// Encoder matching the API: ISO 8601 dates.
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
