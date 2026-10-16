import SharedModels
import SwiftUI

/// Three steps: what you want to read → what you don't → your region on the map.
struct OnboardingFlow: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: OnboardingViewModel?

    var body: some View {
        Group {
            if let model {
                OnboardingContent(model: model, environment: environment)
            } else {
                Theme.background.ignoresSafeArea()
            }
        }
        .task {
            guard model == nil else { return }
            let model = OnboardingViewModel(feed: environment.feed, settings: environment.settings)
            await model.load()
            self.model = model
        }
    }
}

private struct OnboardingContent: View {
    @Bindable var model: OnboardingViewModel
    let environment: AppEnvironment

    var body: some View {
        Group {
            if model.step == .region {
                // Step 3: the map fills the screen; header and button float on top.
                ZStack {
                    RegionMapView(
                        regions: model.regions,
                        cover: model.cover,
                        borders: model.borders,
                        style: environment.settings.mapStyle,
                        selectedId: $model.selectedRegionId,
                        camera: $model.regionCamera,
                        isFadingOut: model.isFadingOut,
                        onFadedOut: model.fadeFinished
                    )
                    .ignoresSafeArea()
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                            StepTitle(title: "Hvor bor du?", subtitle: "Trykk på fylket ditt, så får du lokalavisene der.")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                        .background(alignment: .top) {
                            LinearGradient(stops: [.init(color: Theme.background, location: 0.75), .init(color: Theme.background.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                                .ignoresSafeArea(edges: .top)
                        }
                        Spacer(minLength: 0)
                        nextButton
                    }
                    // Title and button go with the white, so only the map is left for the zoom.
                    .opacity(model.isFadingOut ? 0 : 1)
                    .animation(.easeOut(duration: 0.35), value: model.isFadingOut)
                    .allowsHitTesting(!model.isFadingOut)
                }
            } else {
                VStack(spacing: 0) {
                    header
                    Group {
                        switch model.step {
                        case .interests: InterestsStep(model: model)
                        default: BlacklistStep(model: model)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    nextButton
                }
                .background(Theme.background)
            }
        }
        .sensoryFeedback(.selection, trigger: model.step)
    }

    private var header: some View {
        StepHeader(step: model.step, back: model.back) {
            model.skip(settings: environment.settings, location: environment.location)
        }
    }

    private var nextButton: some View {
        Button(model.step == .region ? "Kom i gang" : "Neste") {
            model.next(settings: environment.settings)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!model.canContinue)
        .opacity(model.canContinue ? 1 : 0.4)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

/// "STEG 1 AV 3" with a progress bar, a back button from step 2 and "Hopp over" on every step.
private struct StepHeader: View {
    let step: OnboardingViewModel.Step
    let back: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if step != .interests {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 36, height: 36)
                            .background(Theme.surface, in: .circle)
                    }
                    .accessibilityLabel("Tilbake")
                }
                Kicker(text: "Steg \(step.number) av \(OnboardingViewModel.Step.allCases.count)")
                Spacer()
                Button("Hopp over", action: skip)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(height: 36)
            HStack(spacing: 6) {
                ForEach(OnboardingViewModel.Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Theme.adressaBlue : Theme.grey)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

/// Step 1: categories to read, plus own interests.
private struct InterestsStep: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StepTitle(title: "Hva vil du lese om?", subtitle: "Velg det som interesserer deg. Vi viser det først på kartet.")
                FlowLayout(spacing: 8) {
                    ForEach(model.categories) { category in
                        ChipButton(title: category.name, symbol: category.symbol, isOn: model.preferred.contains(category.id)) {
                            model.togglePreferred(category.id)
                        }
                    }
                    ForEach(model.interestWords, id: \.self) { word in
                        ChipButton(title: word, symbol: "xmark", isOn: true) {
                            model.interestWords.removeAll { $0 == word }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Kicker(text: "Legg til egne")
                    AddWordField(placeholder: "F.eks. Rosenborg, festival, NTNU", add: model.addInterest)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Step 2: categories and words to hide.
private struct BlacklistStep: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StepTitle(title: "Hva vil du slippe?", subtitle: "Det du velger her, ser du aldri på kartet. Du kan endre det senere.")
                FlowLayout(spacing: 8) {
                    ForEach(model.blockableCategories) { category in
                        ChipButton(title: category.name, symbol: model.blocked.contains(category.id) ? "nosign" : category.symbol, isOn: model.blocked.contains(category.id), tint: Theme.ink) {
                            model.toggleBlocked(category.id)
                        }
                    }
                    ForEach(model.mutedWords, id: \.self) { word in
                        ChipButton(title: word, symbol: "xmark", isOn: true, tint: Theme.ink) {
                            model.mutedWords.removeAll { $0 == word }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Kicker(text: "Skjul ord")
                    AddWordField(placeholder: "F.eks. valg, krim, budsjett", add: model.addMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.headline(30))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.lead)
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
