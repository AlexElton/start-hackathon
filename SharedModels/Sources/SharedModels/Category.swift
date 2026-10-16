/// A news category, e.g. "kultur". `symbol` is an SF Symbol name, `color` a hex string.
public struct Category: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var symbol: String
    public var color: String

    public init(id: String, name: String, symbol: String, color: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
    }
}
