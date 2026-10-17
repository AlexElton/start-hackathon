import UIKit

/// Downloads and caches small images, e.g. pin thumbnails.
final class ImageLoader {
    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 300
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let (data, _) = try? await session.data(from: url),
              let image = await UIImage(data: data)?.byPreparingForDisplay()
        else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Polaris images take a `w` parameter, so pins ask for a small version. Wikimedia photos (in our added mock
    /// content) pick a size in the path instead; 330 px is one of its standard thumbnail sizes.
    static func thumbnailURL(_ string: String?, width: Int) -> URL? {
        guard let string else { return nil }
        if string.contains("upload.wikimedia.org") {
            return URL(string: string.replacingOccurrences(of: #"/\d+px-"#, with: "/330px-", options: .regularExpression))
        }
        guard var components = URLComponents(string: string) else { return nil }
        var items = (components.queryItems ?? []).filter { $0.name != "w" }
        items.append(URLQueryItem(name: "w", value: "\(width)"))
        components.queryItems = items
        return components.url
    }
}
