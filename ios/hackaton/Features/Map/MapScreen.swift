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

    /// After onboarding, things come in one after another instead of all at once:
    /// onboarding fades away, then the chips and slider, then the pins.
    @State private var showChrome: Bool
    @State private var showPins: Bool

    init(model: MapViewModel, environment: AppEnvironment) {
        self.model = model
        self.environment = environment
        let handingOff = environment.settings.isHandingOff
        _showChrome = State(initialValue: !handingOff)
        _showPins = State(initialValue: !handingOff)
    }

    private var chromeVisible: Bool { showChrome && !model.isIntroPlaying }

    var body: some View {
        ZStack(alignment: .top) {
            MapView(
                style: settings.mapStyle,
                initialCamera: model.initialCamera,
                cameraCommand: model.cameraCommand,
                // Pins wait until the camera has landed and onboarding has faded, then pop in.
                items: model.isFlying || !showPins ? [] : model.items,
                zoomFraction: model.zoomFraction,
                isSliderActive: model.isSliderActive,
                images: environment.images,
                onZoomChange: model.mapZoomChanged,
                onRegionChange: model.visibleRegionChanged,
                onSelect: model.open,
                onRendered: {
                    model.mapRendered()
                    settings.mainMapRendered = true
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    // The app's logo, like a small version of the app icon: white glyph on Adressablå.
                    Image("Logo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(width: 40, height: 40)
                        .background(Theme.adressaBlue, in: .rect(cornerRadius: 11, style: .continuous))
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
            // Glides down into place while fading in, instead of just appearing.
            .opacity(chromeVisible ? 1 : 0)
            .offset(y: chromeVisible ? 0 : -14)
            .animation(.smooth(duration: 0.55), value: chromeVisible)

            // Zoom slider: short, centred vertically on the right edge.
            ZoomSlider(value: $model.zoomFraction, isActive: $model.isSliderActive)
                .frame(height: 340)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .opacity(chromeVisible ? 1 : 0)
                .offset(x: chromeVisible ? 0 : 16)
                .animation(.smooth(duration: 0.55), value: chromeVisible)
        }
        .task { await model.playIntroIfNeeded(style: settings.mapStyle, settings: settings) }
        // The tab bar slides up with the rest instead of showing up as onboarding fades.
        .toolbarVisibility(chromeVisible ? .visible : .hidden, for: .tabBar)
        .animation(.smooth(duration: 0.55), value: chromeVisible)
        .onChange(of: settings.isHandingOff) { _, handingOff in
            guard !handingOff else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(380)) // Onboarding's 0.4 s fade.
                showChrome = true
                try? await Task.sleep(for: .milliseconds(220))
                showPins = true
            }
        }
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
