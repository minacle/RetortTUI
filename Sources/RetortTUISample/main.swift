import RetortTUI

@main
struct InputEventsApp: App {

    var body: some Scene {
        WindowGroup {
            CounterView()
        }
    }
}

struct CounterView: View {

    @State private var count = 0

    @State private var lastKey = "none"

    @FocusState private var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("RetortTUI Input Events")
                Spacer()
                Text(isFocused ? "focused" : "unfocused")
            }

            Text("Count: \(count)")
            Text("Last key: \(lastKey)")
            Text("Use Up/k and Down/j. Press r to reset. Press Ctrl-C to exit.")
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(keys: [.upArrow, "k"]) { _ in
            count += 1
            return .handled
        }
        .onKeyPress(keys: [.downArrow, "j"]) { _ in
            count -= 1
            return .handled
        }
        .onKeyPress("r") {
            count = 0
            return .handled
        }
        .onKeyPress(phases: .down) { keyPress in
            lastKey = label(for: keyPress)
            return .ignored
        }
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
}
