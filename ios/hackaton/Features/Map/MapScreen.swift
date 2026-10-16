import SharedModels
import SwiftUI

struct MapScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: MapViewModel?

    var body: some View {
        ZStack {
            if let model {
                MapContent(model: model, environment: environment)
            }
        }
        .task {
            if model == nil {
                model = MapViewModel(feed: environment.feed)
            }
            environment.location.requestPermission()
        }
    }
}

private struct MapContent: View {
    @Bindable var model: MapViewModel
    let environment: AppEnvironment

    var body: some View {
        ZStack(alignment: .top) {
            MapView(
                style: environment.settings.mapStyle,
                items: model.items,
                zoomFraction: model.zoomFraction,
                isSliderActive: model.isSliderActive,
                images: environment.images,
                onZoomChange: model.mapZoomChanged,
                onRegionChange: model.visibleRegionChanged,
                onSelect: model.open
            )
            .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 12) {
                LayerFilterBar(selected: model.layer, select: model.select)
                    .frame(maxWidth: .infinity)

                if let error = model.errorMessage {
                    Button("\(error) – prøv igjen", systemImage: "arrow.clockwise", action: model.retry)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .frame(maxWidth: .infinity)
                }

                ZoomSlider(value: $model.zoomFraction, isActive: $model.isSliderActive)
                    .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .sheet(item: $model.selection) { selection in
            ItemSheetView(selection: selection, feed: model.feed, paperName: model.paperName(for:)) {
                model.selection = nil
            }
        }
    }
}

#Preview {
    let env = AppEnvironment.preview()
    MapScreen()
        .environment(env)
        .environment(env.settings)
}
