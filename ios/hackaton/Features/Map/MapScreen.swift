import SharedModels
import SwiftUI

struct MapScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: MapViewModel?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let model, model.isReady {
                MapContent(model: model, environment: environment)
            }
        }
        .task {
            guard model == nil else { return }
            environment.location.requestPermission()
            let model = MapViewModel(feed: environment.feed)
            await model.prepare(settings: environment.settings, location: environment.location, reduceMotion: reduceMotion)
            self.model = model
        }
    }
}

private struct MapContent: View {
    @Bindable var model: MapViewModel
    let environment: AppEnvironment

    private var settings: SettingsStore { environment.settings }

    var body: some View {
        ZStack(alignment: .top) {
            MapView(
                style: settings.mapStyle,
                initialCamera: model.initialCamera,
                cameraCommand: model.cameraCommand,
                items: model.items,
                zoomFraction: model.zoomFraction,
                isSliderActive: model.isSliderActive,
                images: environment.images,
                onZoomChange: model.mapZoomChanged,
                onRegionChange: model.visibleRegionChanged,
                onSelect: model.open,
                onRendered: model.mapRendered
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    // Logo placeholder: a plain Adressablå circle until we have the real logo.
                    Circle()
                        .fill(Theme.adressaBlue)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .accessibilityHidden(true)
                    LayerFilterBar(selected: model.layer, select: model.select)
                    Spacer(minLength: 0)
                }

                if let error = model.errorMessage {
                    Button("\(error) – prøv igjen", systemImage: "arrow.clockwise", action: model.retry)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            // Chips fade in once the first intro has landed.
            .opacity(model.isIntroPlaying ? 0 : 1)
            .animation(.easeOut(duration: 0.5), value: model.isIntroPlaying)

            // Zoom slider: short, centred vertically on the right edge.
            ZoomSlider(value: $model.zoomFraction, isActive: $model.isSliderActive)
                .frame(height: 340)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .opacity(model.isIntroPlaying ? 0 : 1)
                .animation(.easeOut(duration: 0.5), value: model.isIntroPlaying)
        }
        .task { await model.playIntroIfNeeded(style: settings.mapStyle, settings: settings) }
        .onChange(of: settings.pendingGlobeIntro) { _, replay in
            guard replay else { return }
            settings.pendingGlobeIntro = false
            Task { await model.replayIntro(style: settings.mapStyle, settings: settings) }
        }
        .onChange(of: settings.blockedCategories) { model.applyPreferences(from: settings) }
        .onChange(of: settings.mutedWords) { model.applyPreferences(from: settings) }
        .onChange(of: settings.preferredCategories) { model.applyPreferences(from: settings) }
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
