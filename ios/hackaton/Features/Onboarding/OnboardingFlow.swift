import SharedModels
import SwiftUI

/// Three steps: what you want to read → what you don't → your region on the map.
/// With `onDone` set (opened from Innstillinger) it's just the first two, saved straight back.
struct OnboardingFlow: View {
    var onDone: (() -> Void)?

    @Environment(AppEnvironment.self) private var environment
    @State private var model: OnboardingViewModel?

    var body: some View {
        Group {
            if let model {
                OnboardingContent(model: model, environment: environment, onDone: onDone)
            } else {
                Theme.background.ignoresSafeArea()
            }
        }
        .task {
            guard model == nil else { return }
            let model = OnboardingViewModel(feed: environment.feed, settings: environment.settings, isEditing: onDone != nil)
            await model.load()
            self.model = model
        }
    }
}

private struct OnboardingContent: View {
    @Bindable var model: OnboardingViewModel
    let environment: AppEnvironment
    let onDone: (() -> Void)?

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
                        onFadedOut: model.fadeFinished,
                        diveTarget: model.diveTarget,
                        onLanded: { model.diveLanded(settings: environment.settings) }
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
        StepHeader(step: model.step, steps: model.steps, skipTitle: onDone == nil ? "Hopp over" : "Avbryt", back: model.back) {
            if let onDone {
                onDone()
            } else {
                model.skip(settings: environment.settings, location: environment.location)
            }
        }
    }

    private var nextTitle: String {
        if model.step == .region { return "Kom i gang" }
        return onDone != nil && model.step == model.steps.last ? "Lagre" : "Neste"
    }

    private var nextButton: some View {
        Button(nextTitle) {
            if let onDone, model.step == model.steps.last {
                model.saveChoices(into: environment.settings)
                onDone()
            } else {
                model.next(settings: environment.settings)
            }
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
    let steps: [OnboardingViewModel.Step]
    let skipTitle: String
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
                Kicker(text: "Steg \(step.number) av \(steps.count)")
                Spacer()
                Button(skipTitle, action: skip)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(height: 36)
            HStack(spacing: 6) {
                ForEach(steps, id: \.self) { item in
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
    @State private var showAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StepTitle(title: "Hva vil du lese om?", subtitle: "Velg det som interesserer deg. Vi viser det først på kartet.")
                VStack(alignment: .leading, spacing: 12) {
                    FlowLayout(spacing: 8) {
                        ForEach(visibleCategories) { category in
                            ChipButton(title: category.name, symbol: category.symbol, isOn: model.preferred.contains(category.id)) {
                                model.togglePreferred(category.id)
                            }
                        }
                        ForEach(visibleWords, id: \.self) { word in
                            WordChip(word: word, selected: model.interestWords) { model.toggleInterest(word) }
                        }
                    }
                    ShowMoreButton(isExpanded: $showAll)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Kicker(text: "Legg til egne")
                    AddWordField(placeholder: "F.eks. Rosenborg, festival, NTNU", add: model.addInterest)
                    OwnWords(words: model.ownInterestWords, tint: Theme.adressaBlue) { word in
                        model.interestWords.removeAll { $0 == word }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// The first few, plus anything already picked so a choice never disappears.
    private var visibleCategories: [SharedModels.Category] {
        showAll ? model.categories : model.categories.enumerated()
            .filter { $0.offset < collapsedCount || model.preferred.contains($0.element.id) }.map(\.element)
    }

    private var visibleWords: [String] {
        OnboardingViewModel.interestSuggestions.filter { showAll || OnboardingViewModel.contains($0, in: model.interestWords) }
    }
}

/// Step 2: categories and words to hide.
private struct BlacklistStep: View {
    @Bindable var model: OnboardingViewModel
    @State private var showAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StepTitle(title: "Hva vil du slippe?", subtitle: "Det du velger her, ser du aldri på kartet. Du kan endre det senere.")
                VStack(alignment: .leading, spacing: 12) {
                    FlowLayout(spacing: 8) {
                        ForEach(visibleCategories) { category in
                            ChipButton(title: category.name, symbol: model.blocked.contains(category.id) ? "nosign" : category.symbol, isOn: model.blocked.contains(category.id), tint: Theme.ink) {
                                model.toggleBlocked(category.id)
                            }
                        }
                        ForEach(visibleWords, id: \.self) { word in
                            WordChip(word: word, selected: model.mutedWords, tint: Theme.ink) { model.toggleMuted(word) }
                        }
                    }
                    ShowMoreButton(isExpanded: $showAll)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Kicker(text: "Skjul egne ord")
                    AddWordField(placeholder: "F.eks. valg, budsjett, bompenger", add: model.addMuted)
                    OwnWords(words: model.ownMutedWords, tint: Theme.ink) { word in
                        model.mutedWords.removeAll { $0 == word }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var visibleCategories: [SharedModels.Category] {
        let all = model.blockableCategories
        return showAll ? all : all.enumerated()
            .filter { $0.offset < collapsedCount || model.blocked.contains($0.element.id) }.map(\.element)
    }

    private var visibleWords: [String] {
        OnboardingViewModel.mutedSuggestions.filter {
            showAll || OnboardingViewModel.popularMuted.contains($0) || OnboardingViewModel.contains($0, in: model.mutedWords)
        }
    }
}

/// How many categories show before "Vis flere forslag".
private let collapsedCount = 8

/// "Vis flere forslag" / "Vis færre" under the chips: quiet grey, not a main action.
private struct ShowMoreButton: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Vis færre" : "Vis flere forslag")
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.secondaryInk.opacity(0.7))
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// A ready-made word to tap on and off, among the categories.
private struct WordChip: View {
    let word: String
    let selected: [String]
    var tint: Color = Theme.adressaBlue
    let toggle: () -> Void

    var body: some View {
        let isOn = OnboardingViewModel.contains(word, in: selected)
        ChipButton(title: word, symbol: isOn ? "checkmark" : "plus", isOn: isOn, tint: tint, action: toggle)
    }
}

/// Words the user typed in themselves, each removable.
private struct OwnWords: View {
    let words: [String]
    let tint: Color
    let remove: (String) -> Void

    var body: some View {
        if !words.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(words, id: \.self) { word in
                    ChipButton(title: word, symbol: "xmark", isOn: true, tint: tint) {
                        remove(word)
                    }
                }
            }
            .padding(.top, 4)
        }
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
