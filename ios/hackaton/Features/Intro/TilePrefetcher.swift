import MapKit

/// Warms MapKit's tile cache along an intro's route by rendering off-screen snapshots at a few heights,
/// so the flight doesn't outrun the tiles and flash an empty grid on the way down.
enum TilePrefetcher {
    static func warm(along target: CameraSpec, style: MapStyle, timeout: Duration) async {
        let stops = [1_200_000.0, 450_000, 160_000, 60_000].map {
            CameraSpec(center: target.center, distance: $0, pitch: 0)
        } + [target]
        await withTaskGroup(of: Void.self) { group in
            for stop in stops {
                group.addTask { await snapshot(stop, style: style) }
            }
            group.addTask { try? await Task.sleep(for: timeout) }
            // Go as soon as the time is up, even if a snapshot is still loading.
            await group.next()
            await group.next()
            group.cancelAll()
        }
    }

    private static func snapshot(_ camera: CameraSpec, style: MapStyle) async {
        let options = MKMapSnapshotter.Options()
        options.camera = camera.mkCamera
        options.size = CGSize(width: 400, height: 860)
        options.preferredConfiguration = switch style {
        case .standard: MKStandardMapConfiguration(elevationStyle: .realistic)
        case .hybrid: MKHybridMapConfiguration(elevationStyle: .realistic)
        case .satellite: MKImageryMapConfiguration(elevationStyle: .realistic)
        }
        let snapshotter = MKMapSnapshotter(options: options)
        // Stop rendering when the warm-up times out, so it never competes with the flight for the GPU.
        await withTaskCancellationHandler {
            _ = try? await snapshotter.start()
        } onCancel: {
            snapshotter.cancel()
        }
    }
}
