import Testing
@testable import RetortTUI

@Test func textPreservesContent() {
    let text = Text("Hello")

    #expect(text.content == "Hello")
}

@Test func compositeViewResolvesToTextBody() {
    struct ContentView: View {
        var body: some View {
            Text("Hello from body")
        }
    }

    #expect(ViewResolver.text(from: ContentView()) == "Hello from body")
}

@Test func viewBuilderResolvesMultipleChildrenInOrder() {
    struct ContentView: View {
        var body: some View {
            Text("First")
            Text("Second")
        }
    }

    #expect(ViewResolver.text(from: ContentView()) == "First \nSecond")
}

@Test func emptyBuilderResolvesToNoText() {
    struct ContentView: View {
        var body: some View {}
    }

    #expect(ViewResolver.text(from: ContentView()) == nil)
}

@Test func windowGroupStoresRootView() {
    let scene = WindowGroup {
        Text("Hello, RetortTUI")
    }

    #expect(ViewResolver.text(from: scene.root) == "Hello, RetortTUI")
}

@Test func hStackDefaultSpacingPlacesTextSideBySide() {
    let stack = HStack {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "AB")
}

@Test func hStackExplicitSpacingInsertsSpaces() {
    let stack = HStack(spacing: 1) {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "A B")
}

@Test func vStackDefaultSpacingPlacesTextOnAdjacentRows() {
    let stack = VStack {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "A\nB")
}

@Test func vStackExplicitSpacingInsertsBlankRows() {
    let stack = VStack(spacing: 1) {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "A\n\nB")
}

@Test func hStackAlignsChildrenVertically() {
    let top = HStack(alignment: .top, spacing: 1) {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
        Text("X")
    }
    let center = HStack(alignment: .center, spacing: 1) {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
        Text("X")
    }
    let bottom = HStack(alignment: .bottom, spacing: 1) {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
        Text("X")
    }

    #expect(ViewResolver.block(from: top)?.lines == ["A X", "B  ", "C  "])
    #expect(ViewResolver.block(from: center)?.lines == ["A  ", "B X", "C  "])
    #expect(ViewResolver.block(from: bottom)?.lines == ["A  ", "B  ", "C X"])
}

@Test func vStackAlignsChildrenHorizontally() {
    let leading = VStack(alignment: .leading) {
        Text("A")
        Text("BBB")
    }
    let center = VStack(alignment: .center) {
        Text("A")
        Text("BBB")
    }
    let trailing = VStack(alignment: .trailing) {
        Text("A")
        Text("BBB")
    }

    #expect(ViewResolver.block(from: leading)?.lines == ["A  ", "BBB"])
    #expect(ViewResolver.block(from: center)?.lines == [" A ", "BBB"])
    #expect(ViewResolver.block(from: trailing)?.lines == ["  A", "BBB"])
}

@Test func spacerStoresNormalizedMinimumLength() {
    #expect(Spacer().minLength == nil)
    #expect(Spacer(minLength: 2).minLength == 2)
    #expect(Spacer(minLength: -1).minLength == 0)
}

@Test func hStackSpacerWithoutProposalUsesZeroMinimumLength() {
    let stack = HStack {
        Text("A")
        Spacer()
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "AB")
}

@Test func hStackSpacerFillsProposedColumns() {
    let stack = HStack {
        Text("A")
        Spacer()
        Text("B")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 5))

    #expect(block?.lines == ["A   B"])
}

@Test func hStackSpacersShareRemainingColumns() {
    let stack = HStack {
        Text("A")
        Spacer()
        Text("B")
        Spacer()
        Text("C")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 8))

    #expect(block?.lines == ["A   B  C"])
}

@Test func vStackSpacerFillsProposedRows() {
    let stack = VStack {
        Text("A")
        Spacer()
        Text("B")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(rows: 5))

    #expect(block?.lines == ["A", " ", " ", " ", "B"])
}

@Test func textFrameCentersInViewport() {
    let frame = TextRenderer.frame(
        for: "Hello",
        in: TerminalViewportSize(columns: 400, rows: 240)
    )

    #expect(frame == TextFrame(text: "Hello", row: 120, column: 198))
}

@Test func screenOutputClearsAndMovesCursorBeforeText() {
    let output = TextRenderer.screen(
        for: "Hello",
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;3HHello")
}

@Test func screenOutputCentersMultipleLines() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["A", "B"]),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[2;5HA\u{001B}[3;5HB")
}

@Test func terminalSessionSequencesAreStable() {
    #expect(TerminalControl.enterAlternateScreenSequence == "\u{001B}[?1049h")
    #expect(TerminalControl.hideCursorSequence == "\u{001B}[?25l")
    #expect(TerminalControl.showCursorSequence == "\u{001B}[?25h")
    #expect(TerminalControl.exitAlternateScreenSequence == "\u{001B}[?1049l")
}

@Test func controlCQuitsAndOtherInputProducesKeyPresses() {
    #expect(TerminalControl.input(for: 3) == .quit)
    #expect(TerminalControl.input(for: 27) == .keyPress(KeyPress(key: .escape, characters: "\u{001B}")))
    #expect(TerminalControl.input(for: 113) == .keyPress(KeyPress(key: "q", characters: "q")))
}

@Test func inputEventValueTypesExposeExpectedSemantics() {
    let key: KeyEquivalent = "a"
    let modifiers: EventModifiers = [.shift, .control]
    let phases: KeyPress.Phases = [.down, .repeat]

    #expect(key.character == "a")
    #expect(KeyEquivalent.upArrow.character == "\u{F700}")
    #expect(EventModifiers.all.contains(.command))
    #expect(modifiers.contains(.shift))
    #expect(modifiers.contains(.control))
    #expect(!modifiers.contains(.option))
    #expect(KeyPress.Phases.all.contains(.up))
    #expect(phases.contains(.down))
    #expect(phases.contains(.repeat))
    #expect(KeyPress.Result.handled != .ignored)
}

@Test func terminalParsesPrintableAndUTF8Input() {
    #expect(TerminalControl.input(for: [65]) == .keyPress(KeyPress(key: "A", characters: "A")))
    #expect(
        TerminalControl.input(for: Array("é".utf8))
            == .keyPress(KeyPress(key: "é", characters: "é"))
    )
}

@Test func terminalParsesControlLettersWithControlModifier() {
    #expect(
        TerminalControl.input(for: 1)
            == .keyPress(KeyPress(key: "a", characters: "a", modifiers: .control))
    )
    #expect(
        TerminalControl.input(for: 26)
            == .keyPress(KeyPress(key: "z", characters: "z", modifiers: .control))
    )
}

@Test func terminalParsesSpecialKeys() {
    #expect(TerminalControl.input(for: 13) == .keyPress(KeyPress(key: .return, characters: "\r")))
    #expect(TerminalControl.input(for: 10) == .keyPress(KeyPress(key: .return, characters: "\r")))
    #expect(TerminalControl.input(for: 9) == .keyPress(KeyPress(key: .tab, characters: "\t")))
    #expect(TerminalControl.input(for: 32) == .keyPress(KeyPress(key: .space, characters: " ")))
    #expect(TerminalControl.input(for: 8) == .keyPress(KeyPress(key: .delete, characters: "\u{0008}")))
    #expect(TerminalControl.input(for: 127) == .keyPress(KeyPress(key: .delete, characters: "\u{0008}")))
}

@Test func terminalParsesCommonEscapeSequences() {
    #expect(TerminalControl.input(for: [27, 91, 65]) == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}")))
    #expect(TerminalControl.input(for: [27, 91, 66]) == .keyPress(KeyPress(key: .downArrow, characters: "\u{F701}")))
    #expect(TerminalControl.input(for: [27, 91, 67]) == .keyPress(KeyPress(key: .rightArrow, characters: "\u{F703}")))
    #expect(TerminalControl.input(for: [27, 91, 68]) == .keyPress(KeyPress(key: .leftArrow, characters: "\u{F702}")))
    #expect(TerminalControl.input(for: [27, 91, 72]) == .keyPress(KeyPress(key: .home, characters: "\u{F729}")))
    #expect(TerminalControl.input(for: [27, 91, 70]) == .keyPress(KeyPress(key: .end, characters: "\u{F72B}")))
    #expect(TerminalControl.input(for: [27, 91, 53, 126]) == .keyPress(KeyPress(key: .pageUp, characters: "\u{F72C}")))
    #expect(TerminalControl.input(for: [27, 91, 54, 126]) == .keyPress(KeyPress(key: .pageDown, characters: "\u{F72D}")))
    #expect(TerminalControl.input(for: [27, 91, 51, 126]) == .keyPress(KeyPress(key: .deleteForward, characters: "\u{F728}")))
    #expect(TerminalControl.input(for: [27, 91, 90]) == .none)
}

@Test func stateInitializersProvideWrappedValues() {
    struct Probe {

        @State var wrapped = 1

        @State(initialValue: 2) var initial: Int

        @State var optional: Int?
    }

    let probe = Probe()

    #expect(probe.wrapped == 1)
    #expect(probe.initial == 2)
    #expect(probe.optional == nil)
}

@Test func stateWrappedAndProjectedValuesShareStorage() {
    let state = State(wrappedValue: 1)

    #expect(state.wrappedValue == 1)

    state.wrappedValue = 2
    let binding = state.projectedValue

    #expect(binding.wrappedValue == 2)

    binding.wrappedValue = 3

    #expect(state.wrappedValue == 3)
}

@Test func bindingReadsAndWritesWithClosures() {
    var value = 1
    let binding = Binding(
        get: {
            value
        },
        set: { newValue in
            value = newValue
        }
    )

    #expect(binding.wrappedValue == 1)

    binding.wrappedValue = 2

    #expect(value == 2)
}

@Test func bindingProjectedValueReusesBinding() {
    var value = 1
    let binding = Binding(
        get: {
            value
        },
        set: { newValue in
            value = newValue
        }
    )
    let projected = Binding(projectedValue: binding)

    projected.wrappedValue = 4

    #expect(binding.projectedValue.wrappedValue == 4)
    #expect(value == 4)
}

@Test func constantBindingIgnoresWrites() {
    let binding = Binding.constant("fixed")

    binding.wrappedValue = "changed"

    #expect(binding.wrappedValue == "fixed")
}

@Test func bindingDynamicMemberProjectsNestedValue() {
    struct Episode: Equatable {

        var title: String

        var isFavorite: Bool
    }

    var episode = Episode(title: "Pilot", isFavorite: false)
    let binding = Binding(
        get: {
            episode
        },
        set: { newValue in
            episode = newValue
        }
    )
    let favorite = binding.isFavorite

    #expect(favorite.wrappedValue == false)

    favorite.wrappedValue = true

    #expect(episode == Episode(title: "Pilot", isFavorite: true))
}

@Test func stateBindingMutationInvalidatesAndRerendersRootView() {
    let runtime = StateRuntime()
    let probe = BindingProbe<Int>()

    #expect(runtime.block(from: RootCounterView(probe: probe))?.text == "0")

    probe.binding?.wrappedValue = 1

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: RootCounterView(probe: probe))?.text == "1")
}

@Test func childStatePersistsAcrossParentBodyReevaluation() {
    let runtime = StateRuntime()
    let probe = BindingProbe<Int>()

    #expect(runtime.block(from: ParentCounterView(probe: probe))?.text == "0")

    probe.binding?.wrappedValue = 5

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: ParentCounterView(probe: probe))?.text == "5")
}

@Test func siblingStateCellsAreIndependent() {
    let runtime = StateRuntime()
    let probe = LabeledBindingProbe()

    #expect(runtime.block(from: SiblingCounterView(probe: probe))?.lines == ["0", "0"])

    probe.bindings["first"]?.wrappedValue = 7

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: SiblingCounterView(probe: probe))?.lines == ["7", "0"])

    probe.bindings["second"]?.wrappedValue = 4

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: SiblingCounterView(probe: probe))?.lines == ["7", "4"])
}

@Test func focusStateInitializersProvideWrappedValues() {
    struct Probe {

        @FocusState var isFocused: Bool

        @FocusState var field: FocusField?
    }

    let probe = Probe()

    #expect(probe.isFocused == false)
    #expect(probe.field == nil)
}

@Test func focusStateWrappedValueInitializerProvidesWrappedValues() {
    struct Probe {

        @FocusState var isFocused = true

        @FocusState var field: FocusField? = .first
    }

    let probe = Probe()

    #expect(probe.isFocused == true)
    #expect(probe.field == .first)
}

@Test func focusStateBindingMutationInvalidatesAndRerendersRootView() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    #expect(runtime.block(from: BoolFocusableThenFocusedView(probe: probe))?.text == "A")

    probe.binding?.wrappedValue = true

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: BoolFocusableThenFocusedView(probe: probe))?.text == "A")
    #expect(probe.binding?.wrappedValue == true)
}

@Test func focusableThenFocusedRegistersFocusCandidate() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)
}

@Test func focusedThenFocusableRegistersFocusCandidate() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusedThenFocusableView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusedThenFocusableView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)
}

@Test func falseBooleanFocusStateClearsFocus() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)

    probe.binding?.wrappedValue = false
    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(probe.binding?.wrappedValue == false)
}

@Test func optionalFocusStateMovesBetweenCandidates() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<FocusField?>()

    #expect(runtime.block(from: OptionalFocusView(probe: probe))?.lines == ["First ", "Second"])

    probe.binding?.wrappedValue = .first
    _ = runtime.block(from: OptionalFocusView(probe: probe))

    #expect(probe.binding?.wrappedValue == .first)

    probe.binding?.wrappedValue = .second
    _ = runtime.block(from: OptionalFocusView(probe: probe))

    #expect(probe.binding?.wrappedValue == .second)

    probe.binding?.wrappedValue = nil
    _ = runtime.block(from: OptionalFocusView(probe: probe))

    #expect(probe.binding?.wrappedValue == nil)
}

@Test func focusableFalsePreventsRegistration() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: DisabledFocusableView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: DisabledFocusableView(probe: probe))

    #expect(probe.binding?.wrappedValue == false)
}

@Test func duplicateFocusValuesChooseFirstRenderedCandidate() {
    let runtime = StateRuntime()
    let fieldProbe = FocusBindingProbe<FocusField?>()
    let firstProbe = FocusBindingProbe<Bool>()
    let secondProbe = FocusBindingProbe<Bool>()

    _ = runtime.block(
        from: DuplicateFocusValueView(
            fieldProbe: fieldProbe,
            firstProbe: firstProbe,
            secondProbe: secondProbe
        )
    )

    fieldProbe.binding?.wrappedValue = .first
    _ = runtime.block(
        from: DuplicateFocusValueView(
            fieldProbe: fieldProbe,
            firstProbe: firstProbe,
            secondProbe: secondProbe
        )
    )

    #expect(fieldProbe.binding?.wrappedValue == .first)
    #expect(firstProbe.binding?.wrappedValue == true)
    #expect(secondProbe.binding?.wrappedValue == false)
}

@Test func focusModifiersDoNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    let block = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(block?.text == "A")
}

@Test func keyPressModifierDoesNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()

    let block = runtime.block(
        from: FocusedKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: .handled
        )
    )

    #expect(block?.text == "A")
}

@Test func keyPressDispatchRequiresFocusedView() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FocusedKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        result: .handled
    )

    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(keyProbe.events.isEmpty)
}

@Test func focusedViewReceivesMatchingKeyPress() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FocusedKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        result: .handled
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["child"])
}

@Test func keyPressActionMutatesStateAndInvalidatesView() {
    let runtime = StateRuntime()
    let view = KeyPressStateMutationView()

    #expect(runtime.block(from: view)?.text == "0")

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1")
}

@Test func ignoredKeyPressContinuesToAncestorHandler() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = ParentKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        childResult: .ignored
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["child", "parent"])
}

@Test func handledKeyPressStopsBeforeAncestorHandler() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = ParentKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        childResult: .handled
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["child"])
}

@Test func samePathKeyPressHandlersRunInRegistrationOrder() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = OrderedKeyPressView(focusProbe: focusProbe, keyProbe: keyProbe)

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["second"])
}

@Test func keyPressOverloadsMatchExpectedEvents() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = KeyPressOverloadView(focusProbe: focusProbe, keyProbe: keyProbe)

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "5", characters: "5")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "z", characters: "z", phase: .up)) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .ignored)
    #expect(keyProbe.events == ["exact", "set", "characters", "phase"])
}

private final class BindingProbe<Value> {

    var binding: Binding<Value>?

    func capture(_ binding: Binding<Value>) {
        self.binding = binding
    }
}

private final class LabeledBindingProbe {

    var bindings: [String: Binding<Int>] = [:]

    func capture(_ binding: Binding<Int>, label: String) {
        bindings[label] = binding
    }
}

private final class FocusBindingProbe<Value: Hashable> {

    var binding: FocusState<Value>.Binding?

    func capture(_ binding: FocusState<Value>.Binding) {
        self.binding = binding
    }
}

private final class KeyPressProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private enum FocusField: Hashable {

    case first

    case second
}

private struct CapturedCounterText: View {

    let text: String

    init(_ value: Int, binding: Binding<Int>, probe: BindingProbe<Int>) {
        self.text = String(value)
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
    }
}

private struct LabeledCapturedCounterText: View {

    let text: String

    init(_ value: Int, binding: Binding<Int>, label: String, probe: LabeledBindingProbe) {
        self.text = String(value)
        probe.capture(binding, label: label)
    }

    var body: some View {
        Text(text)
    }
}

private struct RootCounterView: View {

    @State var count = 0

    let probe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(count, binding: $count, probe: probe)
    }
}

private struct ParentCounterView: View {

    let probe: BindingProbe<Int>

    var body: some View {
        ChildCounterView(probe: probe)
    }
}

private struct ChildCounterView: View {

    @State var count = 0

    let probe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(count, binding: $count, probe: probe)
    }
}

private struct SiblingCounterView: View {

    let probe: LabeledBindingProbe

    var body: some View {
        VStack {
            LabeledChildCounterView(label: "first", probe: probe)
            LabeledChildCounterView(label: "second", probe: probe)
        }
    }
}

private struct LabeledChildCounterView: View {

    @State var count = 0

    let label: String

    let probe: LabeledBindingProbe

    var body: some View {
        LabeledCapturedCounterText(
            count,
            binding: $count,
            label: label,
            probe: probe
        )
    }
}

private struct BoolFocusableThenFocusedView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusableThenFocusedText(binding: $isFocused, probe: probe)
    }
}

private struct BoolFocusedThenFocusableView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedThenFocusableText(binding: $isFocused, probe: probe)
    }
}

private struct DisabledFocusableView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusableText(binding: $isFocused, probe: probe)
    }
}

private struct CapturedBoolFocusableThenFocusedText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(binding)
    }
}

private struct CapturedBoolFocusedThenFocusableText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding)
            .focusable()
    }
}

private struct CapturedDisabledFocusableText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable(false)
            .focused(binding)
    }
}

private struct FocusedKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    var body: some View {
        CapturedFocusedKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: result
        )
    }
}

private struct CapturedFocusedKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        result: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.result = result
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("child")
                return result
            }
    }
}

private struct KeyPressStateMutationView: View {

    @State var count = 0

    @FocusState var isFocused = true

    var body: some View {
        Text(String(count))
            .focusable()
            .focused($isFocused)
            .onKeyPress("a") {
                count += 1
                return .handled
            }
    }
}

private struct ParentKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let childResult: KeyPress.Result

    var body: some View {
        VStack {
            CapturedParentChildKeyPressText(
                focusBinding: $isFocused,
                focusProbe: focusProbe,
                keyProbe: keyProbe,
                result: childResult
            )
        }
        .onKeyPress("a") {
            keyProbe.record("parent")
            return .handled
        }
    }
}

private struct CapturedParentChildKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        result: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.result = result
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("child")
                return result
            }
    }
}

private struct OrderedKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    var body: some View {
        CapturedOrderedKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )
    }
}

private struct CapturedOrderedKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("first")
                return .handled
            }
            .onKeyPress("a") {
                keyProbe.record("second")
                return .handled
            }
    }
}

private struct KeyPressOverloadView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    var body: some View {
        CapturedKeyPressOverloadText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )
    }
}

private struct CapturedKeyPressOverloadText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a", phases: [.down, .repeat]) { _ in
                keyProbe.record("exact")
                return .handled
            }
            .onKeyPress(keys: ["b", "c"]) { _ in
                keyProbe.record("set")
                return .handled
            }
            .onKeyPress(characters: .decimalDigits) { _ in
                keyProbe.record("characters")
                return .handled
            }
            .onKeyPress(phases: .up) { _ in
                keyProbe.record("phase")
                return .handled
            }
    }
}

private struct OptionalFocusView: View {

    @FocusState var field: FocusField?

    let probe: FocusBindingProbe<FocusField?>

    var body: some View {
        VStack {
            CapturedOptionalFocusedText(
                "First",
                binding: $field,
                value: .first,
                probe: probe
            )
            CapturedOptionalFocusedText(
                "Second",
                binding: $field,
                value: .second,
                probe: probe
            )
        }
    }
}

private struct CapturedOptionalFocusedText: View {

    let text: String

    let binding: FocusState<FocusField?>.Binding

    let value: FocusField

    init(
        _ text: String,
        binding: FocusState<FocusField?>.Binding,
        value: FocusField,
        probe: FocusBindingProbe<FocusField?>
    ) {
        self.text = text
        self.binding = binding
        self.value = value
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(binding, equals: value)
    }
}

private struct DuplicateFocusValueView: View {

    @FocusState var field: FocusField?

    @FocusState var firstIsFocused: Bool

    @FocusState var secondIsFocused: Bool

    let fieldProbe: FocusBindingProbe<FocusField?>

    let firstProbe: FocusBindingProbe<Bool>

    let secondProbe: FocusBindingProbe<Bool>

    var body: some View {
        VStack {
            DuplicateFocusedText(
                "First",
                fieldBinding: $field,
                boolBinding: $firstIsFocused,
                fieldProbe: fieldProbe,
                boolProbe: firstProbe
            )
            DuplicateFocusedText(
                "Second",
                fieldBinding: $field,
                boolBinding: $secondIsFocused,
                fieldProbe: fieldProbe,
                boolProbe: secondProbe
            )
        }
    }
}

private struct DuplicateFocusedText: View {

    let text: String

    let fieldBinding: FocusState<FocusField?>.Binding

    let boolBinding: FocusState<Bool>.Binding

    init(
        _ text: String,
        fieldBinding: FocusState<FocusField?>.Binding,
        boolBinding: FocusState<Bool>.Binding,
        fieldProbe: FocusBindingProbe<FocusField?>,
        boolProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.fieldBinding = fieldBinding
        self.boolBinding = boolBinding
        fieldProbe.capture(fieldBinding)
        boolProbe.capture(boolBinding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(fieldBinding, equals: .first)
            .focused(boolBinding)
    }
}
