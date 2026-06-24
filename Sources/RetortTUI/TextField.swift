import Foundation

/// A control that displays editable single-line text in the terminal.
public struct TextField<Label: View>: View, TextFieldRenderable {

    public typealias Body = Never

    let text: Binding<String>

    let prompt: Text?

    let label: Label

    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.prompt = prompt
        self.label = label()
    }
}

public extension TextField where Label == Text {

    /// Creates a text field with a text label generated from a title string.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a text field with a text label generated from a title string.
    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) {
            Text(title)
        }
    }
}

struct SubmitView<Content: View>: View, SubmitModifierRenderable {

    typealias Body = Never

    let content: Content

    let action: SubmitAction

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        SubmitContext.withAction(action) {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        SubmitContext.withAction(action) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

struct SubmitAction {

    let actionPath: [Int]?

    let action: () -> Void
}

protocol TextFieldRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol SubmitModifierRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement?
}

public extension View {

    /// Performs an action when the user submits a text field within this view.
    func onSubmit(_ action: @escaping () -> Void) -> some View {
        SubmitView(
            content: self,
            action: SubmitAction(
                actionPath: StateContext.currentPath,
                action: action
            )
        )
    }
}

extension TextField {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let submitAction = SubmitContext.currentAction
        let cursor = runtime?.textFieldCursor(
            at: path,
            initialOffset: text.wrappedValue.count
        )
        cursor?.clamp(in: text.wrappedValue)
        runtime?.registerFocusable(true, at: path)
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: submitAction?.actionPath ?? path,
                matches: {
                    TextFieldInput.matches($0)
                },
                action: {
                    handle($0, cursor: cursor, submitAction: submitAction)
                }
            ),
            at: path
        )

        let text = text.wrappedValue
        let isFocused = runtime?.isFocused(at: path) == true
        cursor?.updateHorizontalScrollOffset(for: text, maxWidth: proposal?.columns)
        let scrollColumn = TerminalText.columnWidth(
            text,
            upToCharacterOffset: cursor?.horizontalScrollOffset ?? 0
        )
        let content = RenderedBlock(
            lines: [displayText],
            cursor: renderedCursor(cursor: cursor, isFocused: isFocused)
        )

        var block = ScrollViewRenderer.render(
            content,
            axes: .horizontal,
            position: ScrollPosition(x: scrollColumn),
            proposal: RenderProposal(columns: proposal?.columns, rows: 1)
        ).block
        block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        return block
    }

    private var displayText: String {
        if !text.wrappedValue.isEmpty {
            return text.wrappedValue
        }
        if let prompt {
            return prompt.content
        }

        return ViewResolver.text(from: label) ?? ""
    }

    private func renderedCursor(
        cursor: TextFieldCursor?,
        isFocused: Bool
    ) -> RenderedCursor? {
        guard isFocused, let cursor else {
            return nil
        }

        return RenderedCursor(
            column: TerminalText.columnWidth(
                text.wrappedValue,
                upToCharacterOffset: cursor.offset
            )
        )
    }

    private func handle(
        _ keyPress: KeyPress,
        cursor: TextFieldCursor?,
        submitAction: SubmitAction?
    ) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow:
            cursor?.moveLeft()
            return .handled
        case .rightArrow:
            cursor?.moveRight(in: text.wrappedValue)
            return .handled
        case .home:
            cursor?.move(to: 0, in: text.wrappedValue)
            return .handled
        case .end:
            cursor?.move(to: text.wrappedValue.count, in: text.wrappedValue)
            return .handled
        case .delete:
            cursor?.deleteBackward(in: text)
            return .handled
        case .deleteForward:
            cursor?.deleteForward(in: text)
            return .handled
        case .return:
            submitAction?.action()
            return .handled
        default:
            guard TextFieldInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            cursor?.insert(keyPress.characters, in: text)
            return .handled
        }
    }
}

final class TextFieldCursor {

    private let invalidate: () -> Void

    private(set) var offset = 0 {
        didSet {
            if offset != oldValue {
                invalidate()
            }
        }
    }

    private(set) var horizontalScrollOffset = 0 {
        didSet {
            if horizontalScrollOffset != oldValue {
                invalidate()
            }
        }
    }

    init(initialOffset: Int, invalidate: @escaping () -> Void) {
        self.offset = max(initialOffset, 0)
        self.invalidate = invalidate
    }

    func clamp(in text: String) {
        move(to: offset, in: text)
        horizontalScrollOffset = min(horizontalScrollOffset, offset)
    }

    func moveLeft() {
        offset = max(offset - 1, 0)
    }

    func moveRight(in text: String) {
        move(to: offset + 1, in: text)
    }

    func move(to offset: Int, in text: String) {
        self.offset = min(max(offset, 0), text.count)
    }

    func updateHorizontalScrollOffset(for text: String, maxWidth: Int?) {
        guard let maxWidth, maxWidth > 0 else {
            horizontalScrollOffset = 0
            return
        }

        let visibleTextWidth = offset == text.count && !text.isEmpty
            ? maxWidth - 1
            : maxWidth
        if TerminalText.columnWidth(text) <= visibleTextWidth {
            horizontalScrollOffset = 0
            return
        }

        if offset < horizontalScrollOffset {
            horizontalScrollOffset = offset
            return
        }

        let visibleUpperOffset = offset < text.count ? offset + 1 : offset
        if TerminalText.columnWidth(
            text,
            lowerCharacterOffset: horizontalScrollOffset,
            upperCharacterOffset: visibleUpperOffset
        ) <= visibleTextWidth {
            return
        }

        var newOffset = offset
        while newOffset > 0 {
            let previousOffset = newOffset - 1
            let width = TerminalText.columnWidth(
                text,
                lowerCharacterOffset: previousOffset,
                upperCharacterOffset: visibleUpperOffset
            )
            guard width <= visibleTextWidth else {
                break
            }

            newOffset = previousOffset
        }

        horizontalScrollOffset = newOffset
    }

    func insert(_ newText: String, in text: Binding<String>) {
        text.wrappedValue.insert(newText, atCharacterOffset: offset)
        offset += newText.count
    }

    func deleteBackward(in text: Binding<String>) {
        guard offset > 0 else {
            return
        }

        text.wrappedValue.removeCharacter(atOffset: offset - 1)
        offset -= 1
    }

    func deleteForward(in text: Binding<String>) {
        guard offset < text.wrappedValue.count else {
            return
        }

        text.wrappedValue.removeCharacter(atOffset: offset)
    }
}

private enum SubmitContext {

    private static let threadKey = "RetortTUI.SubmitContext"

    static var currentAction: SubmitAction? {
        get {
            Thread.current.threadDictionary[threadKey] as? SubmitAction
        }
        set {
            let dictionary = Thread.current.threadDictionary
            if let newValue {
                dictionary[threadKey] = newValue
            }
            else {
                dictionary.removeObject(forKey: threadKey)
            }
        }
    }

    static func withAction<Value>(
        _ action: SubmitAction,
        perform operation: () -> Value
    ) -> Value {
        let previous = currentAction
        currentAction = action
        defer {
            currentAction = previous
        }

        return operation()
    }
}

private enum TextFieldInput {

    static func matches(_ keyPress: KeyPress) -> Bool {
        guard keyPress.phase.contains(.down) || keyPress.phase.contains(.repeat) else {
            return false
        }

        return keyPress.key == .delete
            || keyPress.key == .deleteForward
            || keyPress.key == .end
            || keyPress.key == .home
            || keyPress.key == .leftArrow
            || keyPress.key == .return
            || keyPress.key == .rightArrow
            || isTextInsertion(keyPress)
    }

    static func isTextInsertion(_ keyPress: KeyPress) -> Bool {
        guard keyPress.key.isPrintableCharacter else {
            return false
        }

        guard !keyPress.characters.isEmpty,
              keyPress.modifiers.intersection([.control, .option, .command]).isEmpty else {
            return false
        }

        return keyPress.characters.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
    }
}

private extension KeyEquivalent {

    var isPrintableCharacter: Bool {
        switch self {
        case .upArrow, .downArrow, .leftArrow, .rightArrow,
                .clear, .delete, .deleteForward, .end, .escape,
                .home, .pageDown, .pageUp, .return, .tab:
            return false
        default:
            return true
        }
    }
}

private extension String {

    mutating func insert(_ insertedText: String, atCharacterOffset offset: Int) {
        insert(
            contentsOf: insertedText,
            at: indexAtCharacterOffset(offset)
        )
    }

    mutating func removeCharacter(atOffset offset: Int) {
        remove(at: indexAtCharacterOffset(offset))
    }

    private func indexAtCharacterOffset(_ offset: Int) -> Index {
        index(startIndex, offsetBy: min(max(offset, 0), count))
    }
}
