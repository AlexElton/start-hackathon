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

    @State private var showSidePanel = false
    @State private var panelDrag: CGFloat = 0
    /// Decided at the start of each drag: true = sideways (moves the panel), false = up/down (scrolls the list).
    @State private var panelDragIsSideways: Bool?

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

            // Side panel: swipe in from the left edge to see articles without a place on the map.
            SidePanelOverlay(
                progress: panelProgress,
                width: panelWidth,
                items: model.unplacedItems,
                feed: model.feed,
                paperName: model.paperName(for:),
                drag: panelDragGesture,
                close: { dismissPanel() }
            )

            // Edge affordance: a subtle vertical bar on the left edge, like the home indicator.
            // Swipe right along the edge (or tap it) to open the panel. Hidden until the intro is done.
            PanelEdgeHandle(
                progress: panelProgress,
                isHidden: !chromeVisible,
                drag: panelDragGesture,
                tap: { showSidePanel = true }
            )
        }
        .animation(.snappy(duration: 0.3), value: showSidePanel)
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

    /// The panel is almost full width; the map stays visible on the right.
    private var panelWidth: CGFloat { UIScreen.main.bounds.width - 88 }

    /// 0 = hidden, 1 = fully open. Follows the finger while dragging in either direction.
    private var panelProgress: CGFloat {
        if panelDrag > 0 { return min(panelDrag / panelWidth, 1) }
        return showSidePanel ? 1 : 0
    }

    private func dismissPanel() {
        showSidePanel = false
        panelDrag = 0
    }

    /// Swipe right opens the panel, swipe left closes it — like the system back gesture.
    private var panelDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .global)
                .onChanged { value in
                    guard chromeVisible else { return }
                    if panelDragIsSideways == nil {
                        panelDragIsSideways = abs(value.translation.width) > abs(value.translation.height)
                    }
                    guard panelDragIsSideways == true else { return }
                    if showSidePanel {
                        panelDrag = max(0, panelWidth + min(0, value.translation.width))
                    } else {
                        panelDrag = max(0, value.translation.width)
                    }
                }
                .onEnded { value in
                    defer { panelDragIsSideways = nil }
                    guard panelDragIsSideways == true else { return }
                    let fling = value.predictedEndTranslation.width - value.translation.width
                    if showSidePanel {
                        if panelProgress < 0.7 || fling < -400 { showSidePanel = false }
                    } else {
                        if panelProgress > 0.3 || fling > 400 { showSidePanel = true }
                    }
                    panelDrag = 0
                }
        )
    }
}

/// A grabber line on the left edge, like the one on top of a sheet — the way into the side panel.
/// It nudges right once as the map appears. The invisible strip along the edge is the swipe target.
private struct PanelEdgeHandle: View {
    let progress: CGFloat
    let isHidden: Bool
    let drag: AnyGesture<DragGesture.Value>
    let tap: () -> Void

    @State private var nudge: CGFloat = 0

    var body: some View {
        Color.clear
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 5, height: 48)
                    // A soft shadow keeps it visible on light map areas too.
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .padding(.leading, 7)
                    .offset(x: nudge)
            }
            .gesture(drag)
            .onTapGesture(perform: tap)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .opacity(isHidden || progress > 0.02 ? 0 : 1)
            .allowsHitTesting(!isHidden && progress < 0.02)
            .animation(.easeOut(duration: 0.3), value: isHidden)
            .task(id: isHidden) {
                guard !isHidden else { return }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeOut(duration: 0.2)) { nudge = 6 }
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) { nudge = 0 }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Generelle saker")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tap() }
    }
}

/// Scrim + sliding drawer, driven by the drag progress. Full height, almost full width;
/// the map stays visible on the right.
private struct SidePanelOverlay: View {
    let progress: CGFloat
    let width: CGFloat
    let items: [FeedItem]
    let feed: any FeedServicing
    let paperName: (String?) -> String
    let drag: AnyGesture<DragGesture.Value>
    let close: () -> Void

    var body: some View {
        if progress > 0.001 {
            Color.black.opacity(0.3 * progress)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                .allowsHitTesting(progress > 0.3)
        }
        SidePanelView(items: items, feed: feed, paperName: paperName, close: close)
            .frame(width: width)
            // Alongside the list's own scrolling, not instead of it: up/down scrolls, sideways closes.
            .simultaneousGesture(drag)
            .shadow(color: .black.opacity(0.3), radius: 24, x: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .offset(x: -width + width * progress)
            .allowsHitTesting(progress > 0.5)
    }
}

#Preview {
    let env = AppEnvironment.preview()
    MapScreen()
        .environment(env)
        .environment(env.settings)
}
