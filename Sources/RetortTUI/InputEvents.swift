import Foundation

/// A set of key modifiers that can accompany an input event.
public struct EventModifiers: OptionSet, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let capsLock = EventModifiers(rawValue: 1 << 0)

    public static let shift = EventModifiers(rawValue: 1 << 1)

    public static let control = EventModifiers(rawValue: 1 << 2)

    public static let option = EventModifiers(rawValue: 1 << 3)

    public static let command = EventModifiers(rawValue: 1 << 4)

    public static let numericPad = EventModifiers(rawValue: 1 << 5)

    public static let all: EventModifiers = [
        .capsLock,
        .shift,
        .control,
        .option,
        .command,
        .numericPad,
    ]
}

/// A key value that can be matched against keyboard input.
public struct KeyEquivalent: Equatable, Hashable, Sendable,
    ExpressibleByExtendedGraphemeClusterLiteral,
    ExpressibleByStringLiteral,
    ExpressibleByUnicodeScalarLiteral
{

    public let character: Character

    public init(_ character: Character) {
        self.character = character
    }

    public init(stringLiteral value: String) {
        self.init(Self.character(from: value))
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(Self.character(from: value))
    }

    public init(unicodeScalarLiteral value: String) {
        self.init(Self.character(from: value))
    }

    public static let upArrow = KeyEquivalent("\u{F700}")

    public static let downArrow = KeyEquivalent("\u{F701}")

    public static let leftArrow = KeyEquivalent("\u{F702}")

    public static let rightArrow = KeyEquivalent("\u{F703}")

    public static let clear = KeyEquivalent("\u{F739}")

    public static let delete = KeyEquivalent("\u{0008}")

    public static let deleteForward = KeyEquivalent("\u{F728}")

    public static let end = KeyEquivalent("\u{F72B}")

    public static let escape = KeyEquivalent("\u{001B}")

    public static let home = KeyEquivalent("\u{F729}")

    public static let pageDown = KeyEquivalent("\u{F72D}")

    public static let pageUp = KeyEquivalent("\u{F72C}")

    public static let `return` = KeyEquivalent("\u{000D}")

    public static let space = KeyEquivalent("\u{0020}")

    public static let tab = KeyEquivalent("\u{0009}")

    private static func character(from value: String) -> Character {
        precondition(value.count == 1, "KeyEquivalent requires exactly one character.")

        return value.first!
    }
}

/// A hardware keyboard event delivered to a focused view.
public struct KeyPress: Equatable, Sendable {

    /// Options for matching different phases of a key-press event.
    public struct Phases: OptionSet, Sendable {

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let down = Phases(rawValue: 1 << 0)

        public static let up = Phases(rawValue: 1 << 1)

        public static let `repeat` = Phases(rawValue: 1 << 2)

        public static let all: Phases = [.down, .up, .repeat]
    }

    /// A result value that indicates whether an action consumed the event.
    public enum Result: Equatable, Hashable, Sendable {

        case handled

        case ignored
    }

    public let key: KeyEquivalent

    public let characters: String

    public let modifiers: EventModifiers

    public let phase: Phases

    public init(
        key: KeyEquivalent,
        characters: String,
        modifiers: EventModifiers = [],
        phase: Phases = .down
    ) {
        self.key = key
        self.characters = characters
        self.modifiers = modifiers
        self.phase = phase
    }
}

struct KeyPressView<Content: View>: View, InputModifierRenderable {

    typealias Body = Never

    let content: Content

    let handler: KeyPressHandler

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerKeyPressHandler(handler, at: path)
        return ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        runtime?.registerKeyPressHandler(handler, at: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }
}

struct KeyPressHandler {

    let actionPath: [Int]?

    let matches: (KeyPress) -> Bool

    let action: (KeyPress) -> KeyPress.Result
}

protocol InputModifierRenderable {

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

    /// Performs an action if the user presses a key while this view has focus.
    func onKeyPress(
        _ key: KeyEquivalent,
        action: @escaping () -> KeyPress.Result
    ) -> some View {
        onKeyPress(key, phases: [.down, .repeat]) {
            _ in

            action()
        }
    }

    /// Performs an action if the user presses any key while this view has focus.
    func onKeyPress(
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        KeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: {
                    phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action if the user presses a key while this view has focus.
    func onKeyPress(
        _ key: KeyEquivalent,
        phases: KeyPress.Phases,
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        onKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action if the user presses one or more keys while this view has focus.
    func onKeyPress(
        keys: Set<KeyEquivalent>,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        KeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: {
                    keys.contains($0.key) && phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action if the user presses keys that generate matching characters.
    func onKeyPress(
        characters: CharacterSet,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        KeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: { keyPress in
                    !keyPress.characters.isEmpty
                        && keyPress.characters.unicodeScalars.allSatisfy {
                            characters.contains($0)
                        }
                        && phases.contains(keyPress.phase)
                },
                action: action
            )
        )
    }
}

final class InputRuntime {

    private var handlersByPath: [[Int]: [KeyPressHandler]] = [:]

    func beginRender() {
        handlersByPath = [:]
    }

    func register(_ handler: KeyPressHandler, at path: [Int]) {
        handlersByPath[path, default: []].append(handler)
    }

    func dispatch(
        _ keyPress: KeyPress,
        from focusedPath: [Int],
        perform: ([Int], () -> KeyPress.Result) -> KeyPress.Result
    ) -> KeyPress.Result {
        var path = focusedPath

        while true {
            if dispatch(keyPress, at: path, perform: perform) == .handled {
                return .handled
            }

            guard !path.isEmpty else {
                return .ignored
            }

            path.removeLast()
        }
    }

    private func dispatch(
        _ keyPress: KeyPress,
        at path: [Int],
        perform: ([Int], () -> KeyPress.Result) -> KeyPress.Result
    ) -> KeyPress.Result {
        for handler in handlersByPath[path] ?? [] where handler.matches(keyPress) {
            let actionPath = handler.actionPath ?? path
            if perform(actionPath, { handler.action(keyPress) }) == .handled {
                return .handled
            }
        }

        return .ignored
    }
}
