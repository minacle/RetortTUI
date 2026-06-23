import Foundation

/// A scrollable axis.
public enum Axis: Sendable {

    case horizontal

    case vertical

    /// A set of scrollable axes.
    public struct Set: OptionSet, Sendable {

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let horizontal = Set(rawValue: 1 << 0)

        public static let vertical = Set(rawValue: 1 << 1)

        public static let all: Set = [.horizontal, .vertical]
    }
}

/// An edge of a scrollable content region.
public enum Edge: Equatable, Sendable {

    case top

    case bottom

    case leading

    case trailing
}

/// A terminal-native point in scrollable content.
public struct ScrollPoint: Equatable, Sendable {

    public let x: Int

    public let y: Int

    public init(x: Int = 0, y: Int = 0) {
        self.x = max(x, 0)
        self.y = max(y, 0)
    }
}

/// A semantic position within a scroll view.
public struct ScrollPosition: Equatable, Sendable {

    private enum Storage: Equatable, Sendable {

        case automatic

        case point(ScrollPoint)

        case edge(Edge)
    }

    private var storage: Storage

    public var point: ScrollPoint? {
        guard case .point(let point) = storage else {
            return nil
        }

        return point
    }

    public var x: Int? {
        point?.x
    }

    public var y: Int? {
        point?.y
    }

    public var edge: Edge? {
        guard case .edge(let edge) = storage else {
            return nil
        }

        return edge
    }

    public init() {
        self.storage = .automatic
    }

    public init(point: ScrollPoint) {
        self.storage = .point(point)
    }

    public init(x: Int) {
        self.init(point: ScrollPoint(x: x))
    }

    public init(y: Int) {
        self.init(point: ScrollPoint(y: y))
    }

    public init(x: Int, y: Int) {
        self.init(point: ScrollPoint(x: x, y: y))
    }

    public init(edge: Edge) {
        self.storage = .edge(edge)
    }

    public mutating func scrollTo(point: ScrollPoint) {
        storage = .point(point)
    }

    public mutating func scrollTo(x: Int) {
        storage = .point(ScrollPoint(x: x))
    }

    public mutating func scrollTo(y: Int) {
        storage = .point(ScrollPoint(y: y))
    }

    public mutating func scrollTo(x: Int, y: Int) {
        storage = .point(ScrollPoint(x: x, y: y))
    }

    public mutating func scrollTo(edge: Edge) {
        storage = .edge(edge)
    }
}

/// A scrollable view.
public struct ScrollView<Content: View>: View {

    public typealias Body = Never

    let axes: Axis.Set

    let content: Content

    public init(
        _ axes: Axis.Set = .vertical,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.content = content()
    }
}

struct ScrollPositionView<Content: View>: View, ScrollPositionModifierRenderable {

    typealias Body = Never

    let content: Content

    let position: Binding<ScrollPosition>

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ScrollPositionContext.withPosition(position) {
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
        ScrollPositionContext.withPosition(position) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

protocol ScrollRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol ScrollPositionModifierRenderable {

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

    /// Associates a binding to a scroll position with scroll views within this view.
    func scrollPosition(_ position: Binding<ScrollPosition>) -> some View {
        ScrollPositionView(content: self, position: position)
    }
}

extension ScrollView: ScrollRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let contentBlock = ViewResolver.block(
            from: content,
            in: contentProposal(from: proposal),
            path: path + [0],
            runtime: runtime
        ) else {
            return nil
        }

        let position = ScrollPositionContext.currentPosition
        let result = ScrollViewRenderer.render(
            contentBlock,
            axes: axes,
            position: position,
            proposal: proposal
        )
        if position.point != nil || position.edge != nil {
            ScrollPositionContext.updateCurrentPosition(to: ScrollPosition(point: result.point))
        }
        return result.block
    }

    private func contentProposal(from proposal: RenderProposal?) -> RenderProposal {
        RenderProposal(
            columns: axes.contains(.horizontal) ? nil : proposal?.columns,
            rows: axes.contains(.vertical) ? nil : proposal?.rows
        )
    }
}

private enum ScrollPositionContext {

    private static let threadKey = "RetortTUI.ScrollPositionContext"

    static var currentPosition: ScrollPosition {
        currentBinding?.wrappedValue ?? ScrollPosition()
    }

    static func withPosition<Value>(
        _ position: Binding<ScrollPosition>,
        perform operation: () -> Value
    ) -> Value {
        let previous = currentBinding
        currentBinding = position
        defer {
            currentBinding = previous
        }

        return operation()
    }

    static func updateCurrentPosition(to position: ScrollPosition) {
        guard let binding = currentBinding, binding.wrappedValue != position else {
            return
        }

        binding.wrappedValue = position
    }

    private static var currentBinding: Binding<ScrollPosition>? {
        get {
            Thread.current.threadDictionary[threadKey] as? Binding<ScrollPosition>
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
}

enum ScrollViewRenderer {

    struct Result {

        var block: RenderedBlock

        var point: ScrollPoint
    }

    static func render(
        _ content: RenderedBlock,
        axes: Axis.Set,
        position: ScrollPosition,
        proposal: RenderProposal?
    ) -> Result {
        let width = proposal?.columns ?? content.width
        let height = proposal?.rows ?? content.height
        guard width > 0, height > 0 else {
            return Result(block: RenderedBlock(lines: []), point: ScrollPoint())
        }

        let point = resolvedPoint(
            from: position,
            content: content,
            width: width,
            height: height
        )
        let x = axes.contains(.horizontal) ? point.x : 0
        let y = axes.contains(.vertical) ? point.y : 0
        let clampedX = min(x, maxHorizontalOffset(for: content, width: width))
        let clampedY = min(y, max(content.height - height, 0))
        let paddedLines = content.lines.map {
            TerminalText.padded($0, toWidth: content.width)
        }
        let blankLine = String(repeating: " ", count: content.width)

        let lines = (0..<height).map { row -> String in
            let sourceRow = clampedY + row
            let line = sourceRow < paddedLines.count ? paddedLines[sourceRow] : blankLine
            return TerminalText.slice(line, fromColumn: clampedX, width: width)
        }

        return Result(
            block: RenderedBlock(
                lines: lines,
                cursor: cursor(
                    from: content.cursor,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height,
                    constrainToBounds: proposal?.columns != nil
                )
            ),
            point: ScrollPoint(x: clampedX, y: clampedY)
        )
    }

    private static func cursor(
        from cursor: RenderedCursor?,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        constrainToBounds: Bool
    ) -> RenderedCursor? {
        guard let cursor else {
            return nil
        }

        let row = cursor.row - y
        let column = cursor.column - x
        guard row >= 0, row < height, column >= 0, column <= width else {
            return nil
        }

        return RenderedCursor(
            row: row,
            column: constrainToBounds ? min(column, width - 1) : column
        )
    }

    private static func maxHorizontalOffset(for content: RenderedBlock, width: Int) -> Int {
        let cursorAllowance = content.cursor == nil || content.width < width ? 0 : 1
        var offset = max(content.width - width + cursorAllowance, 0)
        while offset > 0 && content.lines.contains(where: { line in
            !TerminalText.isCharacterBoundary(line, atColumn: offset)
        }) {
            offset += 1
        }
        return offset
    }

    private static func resolvedPoint(
        from position: ScrollPosition,
        content: RenderedBlock,
        width: Int,
        height: Int
    ) -> ScrollPoint {
        if let point = position.point {
            return point
        }

        switch position.edge {
        case .top:
            return ScrollPoint(y: 0)
        case .bottom:
            return ScrollPoint(y: max(content.height - height, 0))
        case .leading:
            return ScrollPoint(x: 0)
        case .trailing:
            return ScrollPoint(x: max(content.width - width, 0))
        case nil:
            return ScrollPoint()
        }
    }
}
