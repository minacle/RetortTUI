import Foundation
import Testing
@testable import RetortTUI

@Test func textPreservesContent() {
    let text = Text("Hello")

    #expect(text.content == "Hello")
}

@Test func textFieldDisplaysBoundText() {
    var value = "mayu"
    let textField = TextField(
        "Name",
        text: Binding(
            get: {
                value
            },
            set: { newValue in
                value = newValue
            }
        )
    )

    #expect(ViewResolver.text(from: textField) == "mayu")
}

@Test func emptyTextFieldDisplaysPromptBeforeTitle() {
    let textField = TextField(
        "Name",
        text: .constant(""),
        prompt: Text("Required")
    )

    #expect(ViewResolver.text(from: textField) == "Required")
}

@Test func emptyTextFieldDisplaysTitleWhenPromptIsAbsent() {
    let textField = TextField("Name", text: .constant(""))

    #expect(ViewResolver.text(from: textField) == "Name")
}

@Test func focusedTextFieldEditsBoundTextContinuously() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    #expect(runtime.block(from: view)?.text == "Name")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Name")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 0))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "a")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "c", characters: "c", modifiers: .control)) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "a")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
}

@Test func focusedTextFieldMovesCaretWithHorizontalArrows() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "ab")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "ab")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))

    #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "acb")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "acb")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 3))
}

@Test func focusedTextFieldCursorComposesThroughStacks() {
    let runtime = StateRuntime()
    let view = LabeledTextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view)

    #expect(block?.lines == ["Label: Name"])
    #expect(block?.cursor == RenderedCursor(column: 7))
}

@Test func focusedTextFieldCursorUsesTerminalColumnWidth() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "한A")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 3))
}

@Test func focusedTextFieldScrollsHorizontallyToKeepCaretVisible() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView().frame(width: 3)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    for character in "abcd" {
        #expect(
            runtime.dispatch(
                KeyPress(key: KeyEquivalent(character), characters: String(character))
            ) == .handled
        )
    }

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["cd "])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["bcd"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 0))
}

@Test func focusedTextFieldScrollsWideTextByTerminalColumns() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView().frame(width: 3)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "B", characters: "B")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["AB "])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))
}

@Test func focusedTextFieldDoesNotScrollExactWideTextFit() {
    let runtime = StateRuntime()
    let text = String(repeating: "ㅁ", count: 16)
    let view = TextFieldInitialTextView(text: text)
        .frame(width: 32)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view)

    #expect(block?.lines == [String(repeating: "ㅁ", count: 15) + "  "])
    #expect(block?.cursor == RenderedCursor(column: 30))
}

@Test func focusedTextFieldScrollsRightWhenNextWideCharacterIsHidden() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "ㄱㄴㄷㄹㅁ")
        .frame(width: 6)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["ㄱㄴㄷ"])

    for _ in 0..<3 {
        #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
    }

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["ㄴㄷㄹ"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 4))
}

@Test func focusedTextFieldDeletionDoesNotScrollIntoWideCharacterMiddle() {
    let runtime = StateRuntime()
    let text = "ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆ"
    let view = TextFieldInitialTextView(text: text)
        .frame(width: 32)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    #expect(runtime.block(from: view)?.lines == ["ㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆ  "])

    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.lines == ["ㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃ  "])
    #expect(block?.cursor == RenderedCursor(column: 30))
}

@Test func framedTextFieldInsertionAtTrailingCaretScrollsBeforeTrailingSibling() {
    let runtime = StateRuntime()
    let text = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcde"
    let view = DelimitedTextFieldView(text: text)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "f", characters: "f")) == .handled)
    #expect(runtime.consumeInvalidation())
    let block = runtime.block(from: view)

    #expect(block?.lines == ["[BCDEFGHIJKLMNOPQRSTUVWXYZabcdef ]"])
    #expect(block?.cursor == RenderedCursor(column: 32))
}

@Test func focusedTextFieldDoesNotInsertVerticalArrowCharacters() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .ignored)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "a")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
}

@Test func textFieldSubmitsWithReturnKey() {
    let runtime = StateRuntime()
    let view = TextFieldSubmitView()

    #expect(runtime.block(from: view)?.lines == ["Name", "none"])
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["a", "a"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
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

@Test func renderedBlockWidthUsesTerminalColumns() {
    let block = ViewResolver.block(from: Text("한A"))

    #expect(block?.width == 3)
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

@Test func vStackAlignsWideTextByTerminalColumns() {
    let stack = VStack(alignment: .trailing) {
        Text("한")
        Text("ABC")
    }

    #expect(ViewResolver.block(from: stack)?.lines == [" 한", "ABC"])
}

@Test func spacerStoresNormalizedMinimumLength() {
    #expect(Spacer().minLength == nil)
    #expect(Spacer(minLength: 2).minLength == 2)
    #expect(Spacer(minLength: -1).minLength == 0)
}

@Test func geometryValuesNormalizeNegativeComponents() {
    let size = GeometrySize(columns: -1, rows: -2)
    let point = GeometryPoint(column: -3, row: -4)
    let frame = GeometryFrame(origin: point, size: size)

    #expect(size == GeometrySize())
    #expect(point == GeometryPoint())
    #expect(frame == GeometryFrame())
}

@Test func geometryReaderPassesProposedSizeToProxy() {
    let reader = GeometryReader { proxy in
        Text("\(proxy.size.columns)x\(proxy.size.rows)")
    }

    let block = ViewResolver.block(
        from: reader,
        in: RenderProposal(columns: 5, rows: 2)
    )

    #expect(block?.lines == ["5x2  ", "     "])
}

@Test func geometryReaderWithoutProposalUsesZeroSizeAndNaturalContent() {
    let reader = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }

    let block = ViewResolver.block(from: reader)

    #expect(block?.lines == ["0x0"])
}

@Test func geometryProxyColumnsRowsAndFrameMirrorSize() {
    let proxy = GeometryProxy(columns: 7, rows: 1)

    #expect(proxy.columns == 7)
    #expect(proxy.rows == 1)
    #expect(proxy.frame == GeometryFrame(size: GeometrySize(columns: 7, rows: 1)))
}

@Test func geometryReaderExposesLocalFrameFromProposal() {
    let reader = GeometryReader { proxy in
        Text(
            "\(proxy.frame.origin.column),\(proxy.frame.origin.row),"
                + "\(proxy.frame.size.columns),\(proxy.frame.size.rows)"
        )
    }

    let block = ViewResolver.block(
        from: reader,
        in: RenderProposal(columns: 7, rows: 1)
    )

    #expect(block?.lines == ["0,0,7,1"])
}

@Test func geometryReaderUsesStackAxisProposals() {
    let vertical = VStack {
        GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
    }
    let horizontal = HStack {
        GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
    }

    let verticalBlock = ViewResolver.block(
        from: vertical,
        in: RenderProposal(columns: 6, rows: 2)
    )
    let horizontalBlock = ViewResolver.block(
        from: horizontal,
        in: RenderProposal(columns: 6, rows: 2)
    )

    #expect(verticalBlock?.lines == ["6x0   "])
    #expect(horizontalBlock?.lines == ["0x2", "   "])
}

@Test func geometryReaderClipsAndPadsKnownProposedAxes() {
    let reader = GeometryReader { _ in
        Text("ABCDE")
    }

    let block = ViewResolver.block(
        from: reader,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["ABC", "   "])
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

@Test func scrollViewClipsVerticallyByDefault() {
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }

    let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

    #expect(block?.lines == ["A", "B"])
}

@Test func scrollViewClipsHorizontally() {
    let scrollView = ScrollView(.horizontal) {
        Text("ABCDE")
    }

    let block = ViewResolver.block(from: scrollView, in: RenderProposal(columns: 3))

    #expect(block?.lines == ["ABC"])
}

@Test func scrollViewAppliesPointPositionOnBothAxes() {
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(.constant(ScrollPosition(point: ScrollPoint(x: 1, y: 1))))

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["GHI", "LMN"])
}

@Test func scrollPositionMutatingMethodsReplacePosition() {
    var position = ScrollPosition()
    #expect(position.point == nil)
    #expect(position.edge == nil)

    position.scrollTo(point: ScrollPoint(x: 1, y: 2))
    #expect(position.point == ScrollPoint(x: 1, y: 2))
    #expect(position.x == 1)
    #expect(position.y == 2)

    position.scrollTo(x: 4)
    #expect(position.point == ScrollPoint(x: 4, y: 0))

    position.scrollTo(y: 5)
    #expect(position.point == ScrollPoint(x: 0, y: 5))

    position.scrollTo(x: 6, y: 7)
    #expect(position.point == ScrollPoint(x: 6, y: 7))

    position.scrollTo(edge: .bottom)
    #expect(position.point == nil)
    #expect(position.edge == .bottom)
}

@Test func scrollPositionNormalizesNegativeCoordinates() {
    #expect(ScrollPoint(x: -1, y: -2) == ScrollPoint())
    #expect(ScrollPosition(x: -3).point == ScrollPoint())
    #expect(ScrollPosition(y: -4).point == ScrollPoint())
    #expect(ScrollPosition(x: -5, y: -6).point == ScrollPoint())
}

@Test func scrollViewResolvesEdgePositions() {
    let vertical = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .scrollPosition(.constant(ScrollPosition(edge: .bottom)))
    let horizontal = ScrollView(.horizontal) {
        Text("ABCDE")
    }
    .scrollPosition(.constant(ScrollPosition(edge: .trailing)))

    let verticalBlock = ViewResolver.block(from: vertical, in: RenderProposal(rows: 2))
    let horizontalBlock = ViewResolver.block(from: horizontal, in: RenderProposal(columns: 3))

    #expect(verticalBlock?.lines == ["B", "C"])
    #expect(horizontalBlock?.lines == ["CDE"])
}

@Test func scrollViewIgnoresPositionOnDisabledAxes() {
    let vertical = ScrollView {
        Text("ABCDE")
    }
    .scrollPosition(.constant(ScrollPosition(x: 2, y: 0)))
    let horizontal = ScrollView(.horizontal) {
        VStack {
            Text("ABC")
            Text("DEF")
        }
    }
    .scrollPosition(.constant(ScrollPosition(x: 0, y: 1)))

    let verticalBlock = ViewResolver.block(
        from: vertical,
        in: RenderProposal(columns: 3, rows: 1)
    )
    let horizontalBlock = ViewResolver.block(
        from: horizontal,
        in: RenderProposal(columns: 3, rows: 1)
    )

    #expect(verticalBlock?.lines == ["ABC"])
    #expect(horizontalBlock?.lines == ["ABC"])
}

@Test func scrollViewClampsOversizedPositions() {
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(.constant(ScrollPosition(x: 99, y: 99)))

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["HIJ", "MNO"])
}

@Test func frameClipsAndPadsToFixedSize() {
    let view = Text("AB").frame(width: 4, height: 2)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == ["AB  ", "    "])
}

@Test func frameClipsWideTextByTerminalColumns() {
    let view = Text("한A").frame(width: 2, height: 1)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == ["한"])
    #expect(block?.width == 2)
}

@Test func frameProvidesViewportToNestedScrollView() {
    let view = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(.constant(ScrollPosition(x: 1, y: 1)))
    .frame(width: 3, height: 2)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == ["GHI", "LMN"])
}

@Test func scrollPositionBindingClampsOversizedPoint() {
    var position = ScrollPosition(x: 99, y: 99)
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["HIJ", "MNO"])
    #expect(position.point == ScrollPoint(x: 2, y: 1))
}

@Test func scrollPositionBindingResolvesEdgeToClampedPoint() {
    var position = ScrollPosition(edge: .bottom)
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )

    let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

    #expect(block?.lines == ["B", "C"])
    #expect(position.point == ScrollPoint(y: 1))
}

@Test func scrollPositionModifierAffectsScrollableDescendantOnly() {
    let scrolled = HStack {
        ScrollView {
            VStack {
                Text("A")
                Text("B")
                Text("C")
            }
        }
    }
    .scrollPosition(.constant(ScrollPosition(y: 1)))
    let unchanged = Text("Hello").scrollPosition(.constant(ScrollPosition(y: 9)))

    let scrolledBlock = ViewResolver.block(from: scrolled, in: RenderProposal(rows: 2))
    let unchangedBlock = ViewResolver.block(from: unchanged, in: RenderProposal(rows: 1))

    #expect(scrolledBlock?.lines == ["B", "C"])
    #expect(unchangedBlock?.lines == ["Hello"])
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

    #expect(output == "\u{001B}[2J\u{001B}[3;3HHello\u{001B}[?25l")
}

@Test func screenOutputCentersMultipleLines() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["A", "B"]),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[2;5HA\u{001B}[3;5HB\u{001B}[?25l")
}

@Test func screenOutputShowsAndPositionsRenderedCursor() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["Hello"], cursor: RenderedCursor(column: 2)),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;3HHello\u{001B}[?25h\u{001B}[3;5H")
}

@Test func screenOutputClipsLinesToViewportWidth() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["ABCDE"]),
        in: TerminalViewportSize(columns: 3, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1HABC\u{001B}[?25l")
}

@Test func screenOutputPositionsRenderedCursorAfterWideText() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["한A"], cursor: RenderedCursor(column: 3)),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;4H한A\u{001B}[?25h\u{001B}[3;7H")
}

@Test func terminalSessionSequencesAreStable() {
    #expect(TerminalControl.enterAlternateScreenSequence == "\u{001B}[?1049h")
    #expect(TerminalControl.hideCursorSequence == "\u{001B}[?25l")
    #expect(TerminalControl.showCursorSequence == "\u{001B}[?25h")
    #expect(TerminalControl.exitAlternateScreenSequence == "\u{001B}[?1049l")
    #expect(TerminalControl.enableMouseTrackingSequence == "\u{001B}[?1000h\u{001B}[?1006h")
    #expect(TerminalControl.disableMouseTrackingSequence == "\u{001B}[?1006l\u{001B}[?1000l")
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
    let mouse = MouseEvent(
        button: .left,
        column: 2,
        row: 3,
        modifiers: .shift,
        phase: .down
    )

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
    #expect(mouse.button == .left)
    #expect(mouse.column == 2)
    #expect(mouse.row == 3)
    #expect(mouse.modifiers == .shift)
    #expect(mouse.phase == .down)
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

@Test func terminalParsesSGRMouseInput() {
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<0;12;3M".utf8))
            == .mouse(MouseEvent(button: .left, column: 12, row: 3, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<0;12;3m".utf8))
            == .mouse(MouseEvent(button: .left, column: 12, row: 3, phase: .up))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<20;1;2M".utf8))
            == .mouse(
                MouseEvent(
                    button: .left,
                    column: 1,
                    row: 2,
                    modifiers: [.shift, .control],
                    phase: .down
                )
            )
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<2;4;5M".utf8))
            == .mouse(MouseEvent(button: .right, column: 4, row: 5, phase: .down))
    )
    #expect(TerminalControl.input(for: Array("\u{001B}[<0;12M".utf8)) == .none)
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

@Test func tapGestureModifierDoesNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()

    let block = runtime.block(
        from: Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }
    )

    #expect(block?.text == "A")
    #expect(tapProbe.events.isEmpty)
}

@Test func tapGestureActionMutatesStateAndInvalidatesView() {
    let runtime = StateRuntime()
    let view = TapGestureStateMutationView()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    #expect(runtime.block(from: view)?.text == "0")

    dispatchClick(to: runtime, column: 1, row: 1, at: date)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1")
}

@Test func tapGestureHitTestingUsesStackCoordinates() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = StackTapGestureView(tapProbe: tapProbe)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1)
    dispatchClick(to: runtime, column: 3, row: 1)
    dispatchClick(to: runtime, column: 1, row: 2)
    dispatchClick(to: runtime, column: 2, row: 1, expecting: .ignored)

    #expect(tapProbe.events == ["left", "right", "bottom"])
}

@Test func tapGestureHitTestingUsesMostSpecificRegion() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = NestedTapGestureView(tapProbe: tapProbe)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1)

    #expect(tapProbe.events == ["child"])
}

@Test func tapGestureHitTestingRespectsFrameClipping() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Text("ABCD")
        .onTapGesture {
            tapProbe.record("tap")
        }
        .frame(width: 2)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 2, row: 1)
    dispatchClick(to: runtime, column: 3, row: 1, expecting: .ignored)

    #expect(tapProbe.events == ["tap"])
}

@Test func tapGestureWaitsForLargerAvailableCounts() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = CountedTapGestureView(tapProbe: tapProbe)
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, at: date)
    #expect(tapProbe.events.isEmpty)

    dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))
    #expect(tapProbe.events.isEmpty)

    dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.2))
    #expect(tapProbe.events == ["three"])
}

@Test func tapGestureTimeoutPerformsLargestReachedCount() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = CountedTapGestureView(tapProbe: tapProbe)
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, at: date)
    dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))

    #expect(tapProbe.events.isEmpty)
    #expect(
        runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.61)) == .handled
    )
    #expect(tapProbe.events == ["two"])
}

@Test func tapGestureIgnoresOtherButtonsAndMismatchedTargets() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Text("A")
        .onTapGesture {
            tapProbe.record("tap")
        }

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .right, column: 1, row: 1, phase: .down)
        ) == .ignored
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 1, phase: .up)
        ) == .ignored
    )

    #expect(tapProbe.events.isEmpty)
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

private final class TapGestureProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private func dispatchClick(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    at date: Date = Date(timeIntervalSinceReferenceDate: 1_000),
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .down),
            at: date
        ) == result
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .up),
            at: date
        ) == result
    )
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

private struct TapGestureStateMutationView: View {

    @State var count = 0

    var body: some View {
        Text(String(count))
            .onTapGesture {
                count += 1
            }
    }
}

private struct StackTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 1) {
                Text("A")
                    .onTapGesture {
                        tapProbe.record("left")
                    }
                Text("B")
                    .onTapGesture {
                        tapProbe.record("right")
                    }
            }
            Text("C")
                .onTapGesture {
                    tapProbe.record("bottom")
                }
        }
    }
}

private struct NestedTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack {
            Text("A")
                .onTapGesture {
                    tapProbe.record("child")
                }
        }
        .onTapGesture {
            tapProbe.record("parent")
        }
    }
}

private struct CountedTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        Text("A")
            .onTapGesture(count: 1) {
                tapProbe.record("one")
            }
            .onTapGesture(count: 2) {
                tapProbe.record("two")
            }
            .onTapGesture(count: 3) {
                tapProbe.record("three")
            }
    }
}

private struct TextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextField("Name", text: $text)
            .focused($isFocused)
    }
}

private struct TextFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextField("Name", text: $text)
            .focused($isFocused)
    }
}

private struct DelimitedTextFieldView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            TextField("Name", text: $text)
                .focused($isFocused)
                .frame(width: 32)
            Text("]")
        }
    }
}

private struct LabeledTextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Label:")
            TextField("Name", text: $text)
                .focused($isFocused)
        }
    }
}

private struct TextFieldSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack {
            TextField("Name", text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
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
