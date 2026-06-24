import Foundation
import RetortTUI

@main
struct RetortTUISampleApp: App {

    var body: some Scene {
        WindowGroup {
            SampleRoot()
        }
    }
}

private struct SampleRoot: View {

    @FocusState private var focusTarget: Field? = .username

    @FocusState private var shortcutsFocused = false

    @State private var profile = Profile()

    @State private var submitted = "none"

    @State private var tapStatus = "none"

    @State private var keyStatus = "none"

    @State private var verticalScroll = ScrollPosition()

    @State private var horizontalScroll = ScrollPosition(x: 0)

    @State private var allAxisScroll = ScrollPosition(point: ScrollPoint(x: 0, y: 0))

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("RetortTUI sample")
            Text("Tab/Shift-Tab changes focus | Esc clears focus | Ctrl-C exits")

            HStack(alignment: .top, spacing: 4) {
                InputAndFocusDemo(
                    profile: $profile,
                    submitted: $submitted,
                    tapStatus: $tapStatus,
                    keyStatus: $keyStatus,
                    focusTarget: $focusTarget,
                    shortcutsFocused: $shortcutsFocused
                )
                ScrollDemo(
                    verticalPosition: $verticalScroll,
                    horizontalPosition: $horizontalScroll,
                    allAxisPosition: $allAxisScroll
                )
            }

            LayoutAndBindingDemo(profile: $profile)
        }
        .padding(.horizontal, 1)
        .onKeyPress(.tab) {
            focusNext()
            return .handled
        }
        .onKeyPress(keys: [.escape]) {
            _ in

            focusTarget = nil
            shortcutsFocused = false
            keyStatus = "cleared focus"
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "[")) {
            _ in

            scrollAllAxes(to: .top)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "]")) {
            _ in

            scrollAllAxes(to: .bottom)
            return .handled
        }
    }

    private func focusNext() {
        switch (focusTarget, shortcutsFocused) {
        case (.username, _):
            focusTarget = .email
        case (.email, _):
            focusTarget = nil
            shortcutsFocused = true
        default:
            shortcutsFocused = false
            focusTarget = .username
        }
    }

    private func scrollAllAxes(to edge: Edge) {
        verticalScroll.scrollTo(edge: edge)
        allAxisScroll.scrollTo(edge: edge)
        keyStatus = "scrolled to \(edge.label)"
    }
}

private enum Field: Hashable {

    case username

    case email
}

private struct Profile {

    var username = ""

    var email = ""

    var note = "dynamic member binding"
}

private struct InputAndFocusDemo: View {

    @Binding var profile: Profile

    @Binding var submitted: String

    @Binding var tapStatus: String

    @Binding var keyStatus: String

    var focusTarget: FocusState<Field?>.Binding

    var shortcutsFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Input and focus")
                .frame(width: 42, alignment: .leading)
            Text("focus: \(focusLabel)")

            HStack(spacing: 1) {
                Text("username")
                    .frame(width: 9, alignment: .trailing)
                Text("[")
                TextField("username", text: $profile.username, prompt: Text("<required>"))
                    .frame(width: 24, alignment: .leading)
                    .focused(focusTarget, equals: .username)
                Text("]")
            }

            HStack(spacing: 1) {
                Text("email")
                    .frame(width: 9, alignment: .trailing)
                Text("[")
                TextField(text: $profile.email, prompt: Text("<required>")) {
                    Text("email")
                }
                .frame(width: 24, alignment: .leading)
                .focused(focusTarget, equals: .email)
                Text("]")
            }
            .onSubmit {
                submitted = "username=\(profile.username), email=\(profile.email)"
            }

            HStack(spacing: 1) {
                Text("constant")
                    .frame(width: 9, alignment: .trailing)
                Text("[")
                TextField("read only", text: .constant("Binding.constant"))
                    .frame(width: 24, alignment: .leading)
                    .focusable(false)
                Text("]")
            }

            HStack(spacing: 1) {
                Text("[user]")
                    .onTapGesture {
                        focusTarget.wrappedValue = .username
                        shortcutsFocused.wrappedValue = false
                        tapStatus = "focused username"
                    }
                Text("[mail]")
                    .onTapGesture {
                        focusTarget.wrappedValue = .email
                        shortcutsFocused.wrappedValue = false
                        tapStatus = "focused email"
                    }
                Text("[tap x1/x2/x3]")
                    .onTapGesture {
                        tapStatus = "single tap"
                    }
                    .onTapGesture(count: 2) {
                        tapStatus = "double tap"
                    }
                    .onTapGesture(count: 3) {
                        tapStatus = "triple tap"
                    }
            }

            Text("shortcut pad: press letters, arrows, Return, Space, Delete")
                .focusable()
                .focused(shortcutsFocused)
                .onKeyPress(phases: .all) { keyPress in
                    keyStatus = "any key \(keyPress.characters)"
                    return .ignored
                }
                .onKeyPress(.return, phases: [.down]) { keyPress in
                    keyStatus = "return phase=\(keyPress.phase.label)"
                    return .handled
                }
                .onKeyPress(.space) {
                    keyStatus = "space"
                    return .handled
                }
                .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .pageUp, .pageDown, .home, .end]) { keyPress in
                    keyStatus = "navigation \(keyPress.key.label)"
                    return .handled
                }
                .onKeyPress(keys: [.delete, .deleteForward, .clear]) { keyPress in
                    keyStatus = "editing \(keyPress.key.label)"
                    return .handled
                }
                .onKeyPress(characters: CharacterSet.alphanumerics) { keyPress in
                    keyStatus = "typed \(keyPress.characters)\(keyPress.modifiers.sampleLabel)"
                    return .handled
                }

            Text("submitted: \(submitted)")
            Text("tap: \(tapStatus)")
            Text("key: \(keyStatus)")
        }
        .padding(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    }

    private var focusLabel: String {
        if shortcutsFocused.wrappedValue {
            return "shortcut pad"
        }

        switch focusTarget.wrappedValue {
        case .username:
            return "username"
        case .email:
            return "email"
        case nil:
            return "none"
        }
    }
}

private struct ScrollDemo: View {

    @Binding var verticalPosition: ScrollPosition

    @Binding var horizontalPosition: ScrollPosition

    @Binding var allAxisPosition: ScrollPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("ScrollView + wheel")
                .frame(width: 44, alignment: .leading)
            Text("v: \(verticalPosition.description)")
            Text("h: \(horizontalPosition.description)")
            Text("xy: \(allAxisPosition.description)")

            HStack(alignment: .top, spacing: 2) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("[top]")
                        .onTapGesture {
                            verticalPosition.scrollTo(edge: .top)
                        }
                    Text("[bottom]")
                        .onTapGesture {
                            verticalPosition.scrollTo(edge: .bottom)
                        }
                    Text("[y 4]")
                        .onTapGesture {
                            verticalPosition.scrollTo(y: 4)
                        }
                }
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEachRows()
                    }
                }
                .scrollPosition($verticalPosition)
                .frame(width: 26, height: 6, alignment: .topLeading)
            }

            HStack(spacing: 1) {
                Text("[left]")
                    .onTapGesture {
                        horizontalPosition.scrollTo(edge: .leading)
                    }
                Text("[right]")
                    .onTapGesture {
                        horizontalPosition.scrollTo(edge: .trailing)
                    }
                Text("[x 12]")
                    .onTapGesture {
                        horizontalPosition.scrollTo(x: 12)
                    }
            }

            ScrollView(.horizontal) {
                Text("horizontal content 0123456789 abcdefghijklmnopqrstuvwxyz")
            }
            .scrollPosition($horizontalPosition)
            .frame(width: 34, height: 1, alignment: .leading)

            HStack(spacing: 1) {
                Text("[origin]")
                    .onTapGesture {
                        allAxisPosition.scrollTo(point: ScrollPoint())
                    }
                Text("[8,3]")
                    .onTapGesture {
                        allAxisPosition.scrollTo(x: 8, y: 3)
                    }
            }

            ScrollView(.all) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("wide row 0 | 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    Text("wide row 1 | 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    Text("wide row 2 | 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    Text("wide row 3 | 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    Text("wide row 4 | 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    Text("wide row 5 | 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                }
            }
            .scrollPosition($allAxisPosition)
            .frame(width: 34, height: 3, alignment: .topLeading)
        }
        .padding(.vertical, 1)
    }
}

private struct ForEachRows: View {

    private let rows = [
        "ScrollPosition()",
        "init(y:)",
        "init(x:y:)",
        "init(edge:)",
        "to(point:)",
        "to(x:)",
        "to(y:)",
        "to(x:y:)",
        "to(edge:)",
        "Axis.Set",
    ]

    var body: some View {
        ForEach(rows.indices) { index in
            Text("row \(String(format: "%02d", index)): \(rows[index])")
        }
    }
}

private struct LayoutAndBindingDemo: View {

    @Binding var profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Layout, geometry, and state")
                .frame(width: 78, alignment: .leading)

            HStack(alignment: .top, spacing: 2) {
                RowLabel("stacks")
                VStack(alignment: .leading, spacing: 0) {
                    Text("left")
                    Text("edge")
                }
                VStack(alignment: .center, spacing: 0) {
                    Text("center")
                    Text("stack")
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text("right")
                    Text("edge")
                }
                .frame(width: 10, alignment: .trailing)
                HStack(alignment: .bottom, spacing: 1) {
                    Text("top")
                    Text("bottom")
                        .frame(height: 2, alignment: .bottom)
                }
                .frame(height: 2, alignment: .topLeading)
                EmptyView()
            }

            HStack(spacing: 1) {
                RowLabel("padding")
                Text("|")
                Text("all")
                    .padding(0)
                Text("|")
                Text("horizontal")
                    .padding(.horizontal, 2)
                Text("|")
                Text("insets")
                    .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 2))
                Text("|")
            }

            HStack(spacing: 1) {
                RowLabel("frames")
                Text("|")
                Text("lead")
                    .frame(width: 8, alignment: .leading)
                Text("|")
                Text("center")
                    .frame(width: 8)
                Text("|")
                Text("trail")
                    .frame(width: 8, alignment: .trailing)
                Text("|")
                HStack(spacing: 0) {
                    Text("[")
                    Spacer(minLength: 4)
                    Text("]")
                }
                .frame(width: 8, alignment: .leading)
                Text("custom")
                    .frame(
                        width: 10,
                        alignment: Alignment(horizontal: .trailing, vertical: .center)
                    )
            }

            HStack(spacing: 1) {
                RowLabel("alignment")
                    .frame(height: 3, alignment: .center)
                Text("TL")
                    .frame(width: 5, height: 3, alignment: .topLeading)
                Text("T")
                    .frame(width: 5, height: 3, alignment: .top)
                Text("TR")
                    .frame(width: 5, height: 3, alignment: .topTrailing)
                Text("L")
                    .frame(width: 5, height: 3, alignment: .leading)
                Text("C")
                    .frame(width: 5, height: 3, alignment: .center)
                Text("R")
                    .frame(width: 5, height: 3, alignment: .trailing)
                Text("BL")
                    .frame(width: 5, height: 3, alignment: .bottomLeading)
                Text("B")
                    .frame(width: 5, height: 3, alignment: .bottom)
                Text("BR")
                    .frame(width: 5, height: 3, alignment: .bottomTrailing)
            }

            HStack(spacing: 2) {
                RowLabel("constraints")
                Text("min")
                    .frame(minWidth: 6, minHeight: 1, alignment: .leading)
                Text("ideal")
                    .frame(idealWidth: 8, idealHeight: 1, alignment: .center)
                Text("ABCDEFGHIJ")
                    .frame(maxWidth: 6, maxHeight: 1, alignment: .trailing)
                Text("fixed")
                    .fixedSize()
                Text("fixed-h")
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 2) {
                RowLabel("geometry")
                GeometryReader { proxy in
                    Text("\(proxy.columns)x\(proxy.rows) @ \(proxy.frame.origin.column),\(proxy.frame.origin.row)")
                }
                .frame(width: 18, height: 1, alignment: .leading)
                TextField("note", text: $profile.note)
                    .frame(width: 24, alignment: .leading)
            }
        }
        .padding(.top, 1)
    }
}

private struct RowLabel: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .frame(width: 12, alignment: .trailing)
    }
}

private extension Edge {

    var label: String {
        switch self {
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        case .leading:
            return "leading"
        case .trailing:
            return "trailing"
        }
    }
}

private extension EventModifiers {

    var sampleLabel: String {
        var labels: [String] = []

        if contains(.capsLock) {
            labels.append("caps")
        }
        if contains(.shift) {
            labels.append("shift")
        }
        if contains(.control) {
            labels.append("control")
        }
        if contains(.option) {
            labels.append("option")
        }
        if contains(.command) {
            labels.append("command")
        }
        if contains(.numericPad) {
            labels.append("num")
        }

        return labels.isEmpty ? "" : " [\(labels.joined(separator: "+"))]"
    }
}

private extension KeyEquivalent {

    var label: String {
        switch self {
        case .upArrow:
            return "up"
        case .downArrow:
            return "down"
        case .leftArrow:
            return "left"
        case .rightArrow:
            return "right"
        case .clear:
            return "clear"
        case .delete:
            return "delete"
        case .deleteForward:
            return "deleteForward"
        case .end:
            return "end"
        case .escape:
            return "escape"
        case .home:
            return "home"
        case .pageDown:
            return "pageDown"
        case .pageUp:
            return "pageUp"
        case .return:
            return "return"
        case .space:
            return "space"
        case .tab:
            return "tab"
        default:
            return String(character)
        }
    }
}

private extension KeyPress.Phases {

    var label: String {
        if self == .down {
            return "down"
        }
        if self == .up {
            return "up"
        }
        if self == .repeat {
            return "repeat"
        }
        if self == .all {
            return "all"
        }

        return "\(rawValue)"
    }
}

private extension ScrollPosition {

    var description: String {
        if let point {
            return "x=\(point.x), y=\(point.y)"
        }
        if let edge {
            return edge.label
        }

        return "auto"
    }
}
