import RetortTUI

@main
struct InputEventsApp: App {

    var body: some Scene {
        WindowGroup {
            ScrollViewDemo()
        }
    }
}

private enum ScrollFocus: Hashable {

    case outer

    case inner
}

struct ScrollViewDemo: View {

    @State private var outerPosition = ScrollPosition()

    @State private var innerPosition = ScrollPosition()

    @State private var lastKey = "none"

    @FocusState private var focusedPane: ScrollFocus? = .outer

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading) {
                Text("RetortTUI ScrollView | focus: \(focusLabel) | outer: \(label(for: outerPosition)) | inner: \(label(for: innerPosition)) | Last key: \(lastKey)")
                Text("Outer focus: h/j/k/l or arrows scroll the full page. Return focuses the subview. Press r to reset. Press Ctrl-C to exit.")
                Text("--------------------------------------------------------------------------------------------------------------")
                Text("00 OUTER ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789")
                Text("01 The root ScrollView receives the terminal viewport proposal.")
                Text("02 This line is intentionally longer than a narrow terminal viewport for horizontal scrolling.")
                Text("03 Scroll down until the nested scroll view enters the visible region, then press Return.")
                Text("04 When the subview is focused, h/j/k/l and arrows scroll inside that smaller viewport.")
                Text("05 Press Escape while the subview is focused to return focus to the outer scroll view.")
                Text("06 --------------------------------------------------------------------------")

                NestedScrollPane(
                    position: $innerPosition,
                    focusedPane: $focusedPane,
                    lastKey: $lastKey
                )

                Text("07 Back in outer content after the nested scroll view.")
                Text("08 The lines below keep the outer view taller than common terminal windows.")
                Text("09 Row nine keeps the content taller than common terminal windows.")
                Text("10 Row ten keeps the content taller than common terminal windows.")
                Text("11 Row eleven keeps the content taller than common terminal windows.")
                Text("12 Row twelve keeps the content taller than common terminal windows.")
                Text("13 Row thirteen keeps the content taller than common terminal windows.")
                Text("14 Row fourteen keeps the content taller than common terminal windows.")
                Text("15 Row fifteen keeps the content taller than common terminal windows.")
                Text("16 Row sixteen keeps the content taller than common terminal windows.")
                Text("17 Row seventeen keeps the content taller than common terminal windows.")
                Text("18 Row eighteen keeps the content taller than common terminal windows.")
                Text("19 Row nineteen keeps the content taller than common terminal windows.")
                Text("20 Row twenty keeps the content taller than common terminal windows.")
                Text("21 Row twenty-one keeps the content taller than common terminal windows.")
                Text("22 Row twenty-two keeps the content taller than common terminal windows.")
                Text("23 Row twenty-three keeps the content taller than common terminal windows.")
                Text("24 Row twenty-four keeps the content taller than common terminal windows.")
                Text("25 Row twenty-five keeps the content taller than common terminal windows.")
                Text("26 Row twenty-six keeps the content taller than common terminal windows.")
                Text("27 Row twenty-seven keeps the content taller than common terminal windows.")
                Text("28 Row twenty-eight keeps the content taller than common terminal windows.")
                Text("29 Row twenty-nine keeps the content taller than common terminal windows.")
                Text("30 Row thirty keeps the content taller than common terminal windows.")
                Text("31 Row thirty-one keeps the content taller than common terminal windows.")
                Text("32 Row thirty-two keeps the content taller than common terminal windows.")
                Text("33 Row thirty-three keeps the content taller than common terminal windows.")
                Text("34 Row thirty-four keeps the content taller than common terminal windows.")
                Text("35 Row thirty-five keeps the content taller than common terminal windows.")
                Text("36 Row thirty-six keeps the content taller than common terminal windows.")
                Text("37 Row thirty-seven keeps the content taller than common terminal windows.")
                Text("38 Row thirty-eight keeps the content taller than common terminal windows.")
                Text("39 Row thirty-nine keeps the content taller than common terminal windows.")
            }
        }
        .scrollPosition($outerPosition)
        .focusable()
        .focused($focusedPane, equals: .outer)
        .onKeyPress(.return) {
            focusedPane = .inner
            lastKey = "return"
            return .handled
        }
        .onKeyPress(keys: [.upArrow, "k"]) { keyPress in
            outerPosition.scrollTo(
                x: outerPosition.x ?? 0,
                y: max((outerPosition.y ?? 0) - 1, 0)
            )
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress(keys: [.downArrow, "j"]) { keyPress in
            outerPosition.scrollTo(x: outerPosition.x ?? 0, y: (outerPosition.y ?? 0) + 1)
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, "h"]) { keyPress in
            outerPosition.scrollTo(
                x: max((outerPosition.x ?? 0) - 1, 0),
                y: outerPosition.y ?? 0
            )
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress(keys: [.rightArrow, "l"]) { keyPress in
            outerPosition.scrollTo(x: (outerPosition.x ?? 0) + 1, y: outerPosition.y ?? 0)
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress("r") {
            outerPosition = ScrollPosition()
            innerPosition = ScrollPosition()
            focusedPane = .outer
            lastKey = "r"
            return .handled
        }
        .onKeyPress(phases: .down) { keyPress in
            lastKey = label(for: keyPress)
            return .ignored
        }
    }

    private var focusLabel: String {
        switch focusedPane {
        case .outer:
            return "outer"
        case .inner:
            return "inner"
        case nil:
            return "none"
        }
    }
}

private struct NestedScrollPane: View {

    @Binding var position: ScrollPosition

    let focusedPane: FocusState<ScrollFocus?>.Binding

    @Binding var lastKey: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading) {
                Text("SUBVIEW SCROLL AREA | focus with Return | leave with Escape | position: \(label(for: position))")
                Text("inner 00 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                Text("inner 01 This smaller viewport has its own ScrollPosition binding.")
                Text("inner 02 Horizontal scrolling should hide the left side of these rows.")
                Text("inner 03 Vertical scrolling should move this nested content independently.")
                Text("inner 04 The outer scroll position should not change while this pane is focused.")
                Text("inner 05 Use Escape to return focus to the outer scroll view.")
                Text("inner 06 ------------------------------------------------------------")
                Text("inner 07 nested content row seven")
                Text("inner 08 nested content row eight")
                Text("inner 09 nested content row nine")
                Text("inner 10 nested content row ten")
                Text("inner 11 nested content row eleven")
                Text("inner 12 nested content row twelve")
                Text("inner 13 nested content row thirteen")
                Text("inner 14 nested content row fourteen")
            }
        }
        .scrollPosition($position)
        .frame(width: 78, height: 8)
        .focusable()
        .focused(focusedPane, equals: .inner)
        .onKeyPress(.escape) {
            focusedPane.wrappedValue = .outer
            lastKey = "escape"
            return .handled
        }
        .onKeyPress(keys: [.upArrow, "k"]) { keyPress in
            position.scrollTo(x: position.x ?? 0, y: max((position.y ?? 0) - 1, 0))
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress(keys: [.downArrow, "j"]) { keyPress in
            position.scrollTo(x: position.x ?? 0, y: (position.y ?? 0) + 1)
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, "h"]) { keyPress in
            position.scrollTo(x: max((position.x ?? 0) - 1, 0), y: position.y ?? 0)
            lastKey = label(for: keyPress)
            return .handled
        }
        .onKeyPress(keys: [.rightArrow, "l"]) { keyPress in
            position.scrollTo(x: (position.x ?? 0) + 1, y: position.y ?? 0)
            lastKey = label(for: keyPress)
            return .handled
        }
    }
}

private func label(for position: ScrollPosition) -> String {
    if let edge = position.edge {
        return "\(edge)"
    }

    return "x: \(position.x ?? 0), y: \(position.y ?? 0)"
}

private func label(for keyPress: KeyPress) -> String {
    switch keyPress.key {
    case .upArrow:
        return "up"
    case .downArrow:
        return "down"
    case .leftArrow:
        return "left"
    case .rightArrow:
        return "right"
    case .return:
        return "return"
    case .tab:
        return "tab"
    case .escape:
        return "escape"
    case .delete:
        return "delete"
    default:
        return keyPress.characters
    }
}
