import FeedEngine
import SharedModels
import Vapor

/// Static lookup data: categories and papers.
struct MetaController: RouteCollection {
    let repository: any ContentRepository

    func boot(routes: any RoutesBuilder) throws {
        routes.get(.constant(API.Path.categories)) { _ in repository.categories }
        routes.get(.constant(API.Path.papers)) { _ in repository.papers }
        routes.get(.constant(API.Path.regions)) { _ in
            Response(status: .ok, headers: ["Content-Type": "application/geo+json"], body: .init(data: repository.regionsGeoJSON))
        }
        routes.get("regions", "norway") { _ in
            Response(status: .ok, headers: ["Content-Type": "application/geo+json"], body: .init(data: repository.norwayGeoJSON))
        }
    }
}

extension SharedModels.Category: @retroactive Content {}
extension Paper: @retroactive Content {}
