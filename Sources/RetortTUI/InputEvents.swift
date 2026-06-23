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

enum MouseButton: Equatable, Hashable, Sendable {

    case left

    case middle

    case right

    case other(Int)
}

struct MouseEvent: Equatable, Sendable {

    enum Phase: Equatable, Sendable {

        case down

        case up
    }

    let button: MouseButton

    let column: Int

    let row: Int

    let modifiers: EventModifiers

    let phase: Phase

    init(
        button: MouseButton,
        column: Int,
        row: Int,
        modifiers: EventModifiers = [],
        phase: Phase
    ) {
        self.button = button
        self.column = max(column, 1)
        self.row = max(row, 1)
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

struct TapGestureView<Content: View>: View, InputModifierRenderable {

    typealias Body = Never

    let content: Content

    let handler: TapGestureHandler

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerTapGestureHandler(handler, at: path)
        guard var block = ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        block.hitRegions.append(RenderedHitRegion(path: path, frame: block.bounds))
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }
}

struct KeyPressHandler {

    let actionPath: [Int]?

    let matches: (KeyPress) -> Bool

    let action: (KeyPress) -> KeyPress.Result
}

struct TapGestureHandler {

    let actionPath: [Int]?

    let count: Int

    let action: () -> Void
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

    /// Performs an action when this view recognizes a tap gesture.
    func onTapGesture(
        count: Int = 1,
        perform action: @escaping () -> Void
    ) -> some View {
        precondition(count >= 1, "onTapGesture count must be greater than zero.")

        return TapGestureView(
            content: self,
            handler: TapGestureHandler(
                actionPath: StateContext.currentPath,
                count: count,
                action: action
            )
        )
    }

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

    private var tapHandlersByPath: [[Int]: [TapGestureHandler]] = [:]

    private var hitRegions: [RenderedHitRegion] = []

    private var rootFrame = TextFrame(text: "", row: 1, column: 1)

    private var pressedTapTarget: [Int]?

    private var tapSequence: TapSequence?

    private let tapTimeout: TimeInterval = 0.5

    var nextTapDeadline: Date? {
        tapSequence?.deadline
    }

    func beginRender() {
        handlersByPath = [:]
        tapHandlersByPath = [:]
    }

    func register(_ handler: KeyPressHandler, at path: [Int]) {
        handlersByPath[path, default: []].append(handler)
    }

    func register(_ handler: TapGestureHandler, at path: [Int]) {
        tapHandlersByPath[path, default: []].append(handler)
    }

    func updateHitRegions(_ hitRegions: [RenderedHitRegion]) {
        self.hitRegions = hitRegions
    }

    func updateRootFrame(_ frame: TextFrame) {
        self.rootFrame = frame
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

    func dispatch(
        _ mouseEvent: MouseEvent,
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        _ = dispatchExpiredTapActions(at: date, perform: perform)

        guard mouseEvent.button == .left else {
            pressedTapTarget = nil
            return .ignored
        }

        switch mouseEvent.phase {
        case .down:
            pressedTapTarget = tapTarget(at: mouseEvent)
            return pressedTapTarget == nil ? .ignored : .handled
        case .up:
            guard let pressedTapTarget else {
                return .ignored
            }

            defer {
                self.pressedTapTarget = nil
            }

            guard tapTarget(at: mouseEvent) == pressedTapTarget else {
                resetTapSequence()
                return .ignored
            }

            return dispatchTap(at: pressedTapTarget, date: date, perform: perform)
        }
    }

    func dispatchExpiredTapActions(
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        guard let sequence = tapSequence,
              date >= sequence.deadline else {
            return .ignored
        }

        defer {
            resetTapSequence()
        }

        guard let count = sequence.pendingCount else {
            return .ignored
        }

        performTapActions(at: sequence.path, count: count, perform: perform)
        return .handled
    }

    private func tapTarget(at mouseEvent: MouseEvent) -> [Int]? {
        let column = mouseEvent.column - rootFrame.column
        let row = mouseEvent.row - rootFrame.row
        return hitRegions
            .filter {
                tapHandlersByPath[$0.path] != nil
                    && $0.frame.contains(column: column, row: row)
            }
            .max {
                if $0.path.count != $1.path.count {
                    return $0.path.count < $1.path.count
                }

                return $0.frame.area > $1.frame.area
            }?
            .path
    }

    private func dispatchTap(
        at path: [Int],
        date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        let handlers = tapHandlersByPath[path] ?? []
        guard let maximumCount = handlers.map(\.count).max() else {
            resetTapSequence()
            return .ignored
        }

        if tapSequence?.path != path || tapSequence?.isExpired(at: date) == true {
            tapSequence = TapSequence(path: path)
        }

        tapSequence?.count += 1
        tapSequence?.deadline = date.addingTimeInterval(tapTimeout)

        guard let sequence = tapSequence else {
            return .ignored
        }

        if handlers.contains(where: { $0.count == sequence.count }) {
            if sequence.count >= maximumCount {
                performTapActions(at: path, count: sequence.count, perform: perform)
                resetTapSequence()
            }
            else {
                tapSequence?.pendingCount = sequence.count
            }
            return .handled
        }

        if let pendingCount = handlers.map(\.count)
            .filter({ $0 <= sequence.count })
            .max() {
            tapSequence?.pendingCount = pendingCount
        }

        if sequence.count >= maximumCount {
            resetTapSequence()
        }

        return .handled
    }

    private func performTapActions(
        at path: [Int],
        count: Int,
        perform: ([Int], () -> Void) -> Void
    ) {
        for handler in tapHandlersByPath[path] ?? [] where handler.count == count {
            perform(handler.actionPath ?? path, handler.action)
        }
    }

    private func resetTapSequence() {
        tapSequence = nil
    }
}

private struct TapSequence {

    let path: [Int]

    var count = 0

    var deadline = Date.distantPast

    var pendingCount: Int?

    func isExpired(at date: Date) -> Bool {
        date >= deadline
    }
}
