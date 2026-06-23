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

@Test func onlyControlCQuits() {
    #expect(TerminalControl.input(for: 3) == .quit)
    #expect(TerminalControl.input(for: 27) == .none)
    #expect(TerminalControl.input(for: 113) == .none)
}
