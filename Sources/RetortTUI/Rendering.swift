import Foundation

struct TerminalViewportSize: Equatable, Sendable {

    var columns: Int

    var rows: Int

    init(columns: Int, rows: Int) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
    }
}

struct TextFrame: Equatable, Sendable {

    var text: String

    var row: Int

    var column: Int
}

struct RenderedCursor: Equatable, Sendable {

    var row: Int

    var column: Int

    init(row: Int = 0, column: Int = 0) {
        self.row = max(row, 0)
        self.column = max(column, 0)
    }
}

struct RenderedRect: Equatable, Sendable {

    var x: Int

    var y: Int

    var width: Int

    var height: Int

    init(x: Int = 0, y: Int = 0, width: Int = 0, height: Int = 0) {
        self.x = x
        self.y = y
        self.width = max(width, 0)
        self.height = max(height, 0)
    }

    var area: Int {
        width * height
    }

    var isEmpty: Bool {
        width == 0 || height == 0
    }

    func contains(column: Int, row: Int) -> Bool {
        !isEmpty
            && column >= x
            && column < x + width
            && row >= y
            && row < y + height
    }

    func offsetBy(x deltaX: Int, y deltaY: Int) -> RenderedRect {
        RenderedRect(
            x: x + deltaX,
            y: y + deltaY,
            width: width,
            height: height
        )
    }

    func clipped(to bounds: RenderedRect) -> RenderedRect? {
        let minX = max(x, bounds.x)
        let minY = max(y, bounds.y)
        let maxX = min(x + width, bounds.x + bounds.width)
        let maxY = min(y + height, bounds.y + bounds.height)
        let rect = RenderedRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        return rect.isEmpty ? nil : rect
    }
}

struct RenderedHitRegion: Equatable, Sendable {

    var path: [Int]

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedHitRegion {
        RenderedHitRegion(path: path, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedHitRegion? {
        frame.clipped(to: bounds).map {
            RenderedHitRegion(path: path, frame: $0)
        }
    }
}

struct RenderedScrollRegion: Equatable, Sendable {

    var path: [Int]

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedScrollRegion {
        RenderedScrollRegion(path: path, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedScrollRegion? {
        frame.clipped(to: bounds).map {
            RenderedScrollRegion(path: path, frame: $0)
        }
    }
}

struct RenderedFocusRegion: Equatable, Sendable {

    var path: [Int]

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedFocusRegion {
        RenderedFocusRegion(path: path, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedFocusRegion? {
        frame.clipped(to: bounds).map {
            RenderedFocusRegion(path: path, frame: $0)
        }
    }
}

struct RenderedBlock: Equatable, Sendable {

    var lines: [String]

    var cursor: RenderedCursor?

    var hitRegions: [RenderedHitRegion]

    var scrollRegions: [RenderedScrollRegion]

    var focusRegions: [RenderedFocusRegion]

    init(
        lines: [String],
        cursor: RenderedCursor? = nil,
        hitRegions: [RenderedHitRegion] = [],
        scrollRegions: [RenderedScrollRegion] = [],
        focusRegions: [RenderedFocusRegion] = []
    ) {
        self.lines = lines
        self.cursor = cursor
        self.hitRegions = hitRegions
        self.scrollRegions = scrollRegions
        self.focusRegions = focusRegions
    }

    var text: String {
        lines.joined(separator: "\n")
    }

    var width: Int {
        lines.map(TerminalText.columnWidth).max() ?? 0
    }

    var height: Int {
        lines.count
    }

    var bounds: RenderedRect {
        RenderedRect(width: width, height: height)
    }

    func framed(width targetWidth: Int, height targetHeight: Int, alignment: Alignment) -> RenderedBlock {
        let targetWidth = max(targetWidth, 0)
        let targetHeight = max(targetHeight, 0)
        guard targetWidth > 0, targetHeight > 0 else {
            return RenderedBlock(lines: [])
        }

        let x = horizontalOffset(
            contentWidth: width,
            containerWidth: targetWidth,
            alignment: alignment.horizontal
        )
        let y = verticalOffset(
            contentHeight: height,
            containerHeight: targetHeight,
            alignment: alignment.vertical
        )
        let lines = (0..<targetHeight).map { row in
            framedLine(
                at: row,
                width: targetWidth,
                x: x,
                y: y
            )
        }

        return RenderedBlock(
            lines: lines,
            cursor: framedCursor(x: x, y: y, width: targetWidth, height: targetHeight),
            hitRegions: framedHitRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            scrollRegions: framedScrollRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            focusRegions: framedFocusRegions(x: x, y: y, width: targetWidth, height: targetHeight)
        )
    }

    func padded(by insets: EdgeInsets) -> RenderedBlock {
        let contentWidth = width
        let targetWidth = contentWidth + insets.horizontal
        let blankLine = String(repeating: " ", count: targetWidth)
        let contentLines = lines.map { line in
            String(repeating: " ", count: insets.leading)
                + TerminalText.slice(line, fromColumn: 0, width: contentWidth)
                + String(repeating: " ", count: insets.trailing)
        }

        return RenderedBlock(
            lines: Array(repeating: blankLine, count: insets.top)
                + contentLines
                + Array(repeating: blankLine, count: insets.bottom),
            cursor: cursor.map {
                RenderedCursor(row: $0.row + insets.top, column: $0.column + insets.leading)
            },
            hitRegions: hitRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            scrollRegions: scrollRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            focusRegions: focusRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            }
        )
    }

    private func framedLine(at row: Int, width targetWidth: Int, x: Int, y: Int) -> String {
        let sourceRow = row - y
        guard lines.indices.contains(sourceRow) else {
            return String(repeating: " ", count: targetWidth)
        }

        let leadingPadding = max(x, 0)
        let visibleWidth = max(targetWidth - leadingPadding, 0)
        return String(repeating: " ", count: leadingPadding)
            + TerminalText.slice(
                lines[sourceRow],
                fromColumn: max(-x, 0),
                width: visibleWidth
            )
    }

    private func framedCursor(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> RenderedCursor? {
        guard let cursor else {
            return nil
        }

        let row = cursor.row + y
        let column = cursor.column + x
        guard row >= 0,
              row < targetHeight,
              column >= 0,
              column <= targetWidth else {
            return nil
        }

        return RenderedCursor(row: row, column: min(column, targetWidth - 1))
    }

    private func framedHitRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedHitRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return hitRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func framedScrollRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedScrollRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return scrollRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func framedFocusRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedFocusRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return focusRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = containerWidth - contentWidth
        switch alignment {
        case .leading:
            return 0
        case .center:
            return padding / 2
        case .trailing:
            return padding
        }
    }

    private func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = containerHeight - contentHeight
        switch alignment {
        case .top:
            return 0
        case .center:
            return padding / 2
        case .bottom:
            return padding
        }
    }
}

struct RenderProposal: Equatable, Sendable {

    var columns: Int?

    var rows: Int?

    init(columns: Int? = nil, rows: Int? = nil) {
        self.columns = columns.map { max($0, 0) }
        self.rows = rows.map { max($0, 0) }
    }

    init(_ viewport: TerminalViewportSize) {
        self.init(columns: viewport.columns, rows: viewport.rows)
    }
}

enum RenderedElement: Equatable, Sendable {

    case block(RenderedBlock)

    case spacer(minLength: Int)
}

struct LayoutTraits: Sendable {

    var flexibleAxes: Axis.Set = []

    func removingFlexibleAxes(_ axes: Axis.Set) -> LayoutTraits {
        var traits = self
        traits.flexibleAxes.subtract(axes)
        return traits
    }
}

protocol LayoutTraitRenderable {

    var layoutTraits: LayoutTraits { get }
}

struct StackChild {

    var traits: LayoutTraits

    var render: (RenderProposal?, Bool) -> RenderedElement?
}

enum LayoutMeasurementContext {

    private static let threadKey = "RetortTUI.LayoutMeasurementContext"

    static var isMeasuring: Bool {
        Thread.current.threadDictionary[threadKey] as? Bool ?? false
    }

    static func withMeasurement<Value>(_ operation: () -> Value) -> Value {
        let previous = isMeasuring
        Thread.current.threadDictionary[threadKey] = true
        defer {
            Thread.current.threadDictionary[threadKey] = previous
        }

        return operation()
    }
}

protocol FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement]

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild]
}

extension FlattenableViewContent {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.vertical(
            renderedElements(in: proposal, path: path, runtime: runtime).map { element in
                StackChild(
                    traits: LayoutTraits(),
                    render: { _, _ in element }
                )
            },
            alignment: .leading,
            spacing: 0,
            proposal: proposal
        )
    }
}

extension Group: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension OptionalViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        guard let content else {
            return []
        }

        return ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        guard let content else {
            return []
        }

        return ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ConditionalViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.elements(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.elements(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }
}

extension LimitedAvailabilityViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ForEach: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let renderedElements = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(
                at: path,
                id: elementID
            ) ?? offset
            let childPath = path + [childIndex]
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.elements(
                from: child,
                in: proposal,
                path: childPath,
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return renderedElements
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let children = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(
                at: path,
                id: elementID
            ) ?? offset
            let childPath = path + [childIndex]
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.stackChildren(
                from: child,
                in: proposal,
                path: childPath,
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return children
    }

    private func contentElement(
        _ element: Data.Element,
        runtime: StateRuntime?
    ) -> Content {
        guard let runtime, let contextPath else {
            return content(element)
        }

        return runtime.withView(at: contextPath) {
            content(element)
        }
    }
}

enum ViewResolver {

    static func text<Content: View>(from view: Content) -> String? {
        block(from: view)?.text
    }

    static func block<Content: View>(from view: Content) -> RenderedBlock? {
        block(from: view, in: nil)
    }

    static func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> RenderedBlock? {
        block(
            from: view,
            in: rootProposal(for: view, proposal: proposal),
            path: [],
            runtime: nil
        )
    }

    static func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        if let text = view as? Text {
            return RenderedBlock(lines: [text.content])
        }

        if view is EmptyView {
            return nil
        }

        if let spacer = view as? Spacer {
            return block(for: spacer, in: proposal)
        }

        if let scroll = view as? any ScrollRenderable {
            return scroll.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let textField = view as? any TextFieldRenderable {
            return textField.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let group = view as? ViewGroup {
            return StackRenderer.vertical(
                group.elements.enumerated().flatMap { index, element in
                    element.stackChildren(
                        in: proposal,
                        path: path + [index],
                        runtime: runtime
                    )
                },
                alignment: .leading,
                spacing: 0,
                proposal: proposal
            )
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any LayoutModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any EnvironmentModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any SubmitModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        let body = runtime?.withView(at: path) {
            view.body
        } ?? view.body
        return block(from: body, in: proposal, path: path + [0], runtime: runtime)
    }

    static func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> RenderedElement? {
        element(from: view, in: proposal, path: [], runtime: nil)
    }

    static func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        if let text = view as? Text {
            return .block(RenderedBlock(lines: [text.content]))
        }

        if view is EmptyView {
            return nil
        }

        if let spacer = view as? Spacer {
            return .spacer(minLength: spacer.minLength ?? 0)
        }

        if let scroll = view as? any ScrollRenderable {
            return scroll.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let textField = view as? any TextFieldRenderable {
            return textField.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let group = view as? ViewGroup {
            return block(
                from: group,
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
        }

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let modifier = view as? any LayoutModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any EnvironmentModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any SubmitModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        let body = runtime?.withView(at: path) {
            view.body
        } ?? view.body
        return element(from: body, in: proposal, path: path + [0], runtime: runtime)
    }

    private static func block(
        for spacer: Spacer,
        in proposal: RenderProposal?
    ) -> RenderedBlock? {
        let minLength = spacer.minLength ?? 0
        let width = max(proposal?.columns ?? minLength, minLength)
        let height = max(proposal?.rows ?? minLength, minLength)
        guard width > 0 || height > 0 else {
            return nil
        }

        let line = String(repeating: " ", count: width)
        return RenderedBlock(lines: Array(repeating: line, count: max(height, 1)))
    }
}

enum TextRenderer {

    static func frame(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> TextFrame {
        frame(for: RenderedBlock(lines: [text]), in: viewport)
    }

    static func frame(
        for block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> TextFrame {
        let row = max(((viewport.rows - block.height) / 2) + 1, 1)
        let column = max(((viewport.columns - block.width) / 2) + 1, 1)
        let text = block.text
        return TextFrame(text: text, row: row, column: column)
    }

    static func screen(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> String {
        screen(for: RenderedBlock(lines: [text]), in: viewport)
    }

    static func screen(
        for block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> String {
        let frame = frame(for: block, in: viewport)
        return TerminalControl.clearScreenSequence
            + block.lines.enumerated().map { offset, line in
                let availableColumns = viewport.columns - frame.column + 1
                return TerminalControl.cursorPositionSequence(
                    row: frame.row + offset,
                    column: frame.column
                ) + TerminalText.prefix(line, maxWidth: availableColumns)
            }.joined()
            + cursorSequence(for: block, in: frame, viewport: viewport)
    }

    private static func cursorSequence(
        for block: RenderedBlock,
        in frame: TextFrame,
        viewport: TerminalViewportSize
    ) -> String {
        guard let cursor = block.cursor else {
            return TerminalControl.hideCursorSequence
        }

        let row = min(max(frame.row + cursor.row, 1), viewport.rows)
        let column = min(max(frame.column + cursor.column, 1), viewport.columns)
        return TerminalControl.showCursorSequence
            + TerminalControl.cursorPositionSequence(row: row, column: column)
    }
}

protocol StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock?

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

extension StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        renderedBlock(in: proposal, path: [], runtime: nil)
    }
}

extension HStack: StackRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.horizontal(
            ViewResolver.stackChildren(
                from: content,
                in: RenderProposal(rows: proposal?.rows),
                path: path + [0],
                runtime: runtime
            ),
            alignment: alignment,
            spacing: spacing,
            proposal: proposal
        )
    }
}

extension VStack: StackRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.vertical(
            ViewResolver.stackChildren(
                from: content,
                in: RenderProposal(columns: proposal?.columns),
                path: path + [0],
                runtime: runtime
            ),
            alignment: alignment,
            spacing: spacing,
            proposal: proposal
        )
    }
}

extension ViewResolver {

    static func blocks<Content: View>(from view: Content) -> [RenderedBlock] {
        if let group = view as? ViewGroup {
            return group.elements.flatMap {
                $0.renderedElements(in: nil, path: [], runtime: nil).compactMap(\.block)
            }
        }

        return block(from: view).map { [$0] } ?? []
    }

    static func elements<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> [RenderedElement] {
        elements(from: view, in: proposal, path: [], runtime: nil)
    }

    static func elements<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.renderedElements(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedElements(in: proposal, path: path, runtime: runtime)
        }

        return element(
            from: view,
            in: proposal,
            path: path,
            runtime: runtime
        ).map { [$0] } ?? []
    }

    static func stackChildren<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.stackChildren(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any FlattenableViewContent {
            return content.stackChildren(in: proposal, path: path, runtime: runtime)
        }

        let traits = layoutTraits(from: view)
        return [
            StackChild(
                traits: traits,
                render: { childProposal, suppressRegistrations in
                    let render = {
                        element(
                            from: view,
                            in: childProposal,
                            path: path,
                            runtime: runtime
                        )
                    }

                    if suppressRegistrations {
                        return LayoutMeasurementContext.withMeasurement {
                            runtime?.withoutRenderRegistrations(render) ?? render()
                        }
                    }

                    return render()
                }
            ),
        ]
    }

    static func layoutTraits<Content: View>(from view: Content) -> LayoutTraits {
        if let traits = view as? any LayoutTraitRenderable {
            return traits.layoutTraits
        }

        guard Content.Body.self != Never.self else {
            return LayoutTraits()
        }

        return layoutTraits(from: view.body)
    }

    static func rootProposal<Content: View>(
        for view: Content,
        proposal: RenderProposal?
    ) -> RenderProposal? {
        guard let traits = view as? any LayoutTraitRenderable else {
            return proposal
        }

        let axes = traits.layoutTraits.flexibleAxes
        guard !axes.isEmpty else {
            return proposal
        }

        return RenderProposal(
            columns: axes.contains(.horizontal) ? proposal?.columns : nil,
            rows: axes.contains(.vertical) ? proposal?.rows : nil
        )
    }
}

private extension RenderedElement {

    var block: RenderedBlock? {
        guard case .block(let block) = self else {
            return nil
        }

        return block
    }
}

enum StackRenderer {

    static func horizontal(
        _ children: [StackChild],
        alignment: VerticalAlignment,
        spacing: Int,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        let items = horizontalItems(from: children, spacing: spacing, proposal: proposal)
        guard !items.isEmpty else {
            return nil
        }

        let height = items.compactMap(\.block?.height).max() ?? 1
        let gap = String(repeating: " ", count: max(spacing, 0))
        let lines = (0..<height).map { row in
            items.map { item in
                switch item.content {
                case .block(let block):
                    return line(from: block, at: row, in: height, alignedBy: alignment)
                case .spacer:
                    return String(repeating: " ", count: item.width)
                }
            }.joined(separator: gap)
        }

        return RenderedBlock(
            lines: lines,
            cursor: horizontalCursor(from: items, height: height, alignment: alignment),
            hitRegions: horizontalHitRegions(from: items, height: height, alignment: alignment),
            scrollRegions: horizontalScrollRegions(from: items, height: height, alignment: alignment),
            focusRegions: horizontalFocusRegions(from: items, height: height, alignment: alignment)
        )
    }

    static func vertical(
        _ children: [StackChild],
        alignment: HorizontalAlignment,
        spacing: Int,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        let items = verticalItems(from: children, spacing: spacing, proposal: proposal)
        guard !items.isEmpty else {
            return nil
        }

        let width = items.compactMap(\.block?.width).max() ?? 0
        let gap = Array(repeating: "", count: max(spacing, 0))
        let lines = items.enumerated().flatMap { index, item in
            let lines: [String]
            switch item.content {
            case .block(let block):
                lines = block.lines.map {
                    line($0, alignedBy: alignment, in: width)
                }
            case .spacer:
                lines = Array(
                    repeating: String(repeating: " ", count: width),
                    count: item.height
                )
            }

            if index == items.indices.last {
                return lines
            }

            return lines + gap
        }

        return RenderedBlock(
            lines: lines,
            cursor: verticalCursor(from: items, width: width, alignment: alignment),
            hitRegions: verticalHitRegions(from: items, width: width, alignment: alignment),
            scrollRegions: verticalScrollRegions(from: items, width: width, alignment: alignment),
            focusRegions: verticalFocusRegions(from: items, width: width, alignment: alignment)
        )
    }

    private struct HorizontalItem {

        var content: RenderedElement

        var x: Int

        var width: Int

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }
    }

    private struct VerticalItem {

        var content: RenderedElement

        var y: Int

        var height: Int

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }
    }

    struct MeasuredChild {

        var content: RenderedElement

        var traits: LayoutTraits

        var render: (RenderProposal?, Bool) -> RenderedElement?
    }

    private static func horizontalItems(
        from children: [StackChild],
        spacing: Int,
        proposal: RenderProposal?
    ) -> [HorizontalItem] {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .horizontal,
            childProposal: horizontalChildProposal
        )
        let flexibleCount = children.horizontalFlexibleCount
        let spacingWidth = spacingWidth(for: children.count, spacing: spacing)
        let minimums = children.horizontalMinimums
        let idealWidth = children.reduce(0) { width, child in
            width + child.content.horizontalLength
        } + spacingWidth
        let targetWidth: Int
        let fixedWidth = fixedHorizontalWidth(from: children)
        if flexibleCount > 0, let columns = proposal?.columns {
            targetWidth = max(columns, fixedWidth + minimums.reduce(0, +) + spacingWidth)
        }
        else {
            targetWidth = idealWidth
        }

        let flexibleLengths = flexibleLengths(
            count: flexibleCount,
            minimums: minimums,
            extra: targetWidth - minimums.reduce(0, +) - fixedWidth - spacingWidth
        )
        var flexibleIndex = 0
        var x = 0
        return children.compactMap { child in
            let element: RenderedElement
            let itemWidth: Int
            switch child.content {
            case .block(let block):
                if child.traits.flexibleAxes.contains(.horizontal) {
                    let width = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                    element = child.render(
                        horizontalChildProposal(
                            width,
                            traits: child.traits,
                            stackProposal: proposal
                        ),
                        false
                    ) ?? .block(block)
                }
                else {
                    element = child.content
                }
                itemWidth = element.horizontalLength
            case .spacer:
                itemWidth = flexibleLengths[flexibleIndex]
                flexibleIndex += 1
                element = child.content
            }

            guard element.isRenderable else {
                return nil
            }

            let item = HorizontalItem(content: element, x: x, width: itemWidth)
            x += item.width + max(spacing, 0)
            return item
        }
    }

    private static func verticalItems(
        from children: [StackChild],
        spacing: Int,
        proposal: RenderProposal?
    ) -> [VerticalItem] {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .vertical,
            childProposal: verticalChildProposal
        )
        let flexibleCount = children.verticalFlexibleCount
        let spacingHeight = spacingWidth(for: children.count, spacing: spacing)
        let minimums = children.verticalMinimums
        let idealHeight = children.reduce(0) { height, child in
            height + child.content.verticalLength
        } + spacingHeight
        let targetHeight: Int
        let fixedHeight = fixedVerticalHeight(from: children)
        if flexibleCount > 0, let rows = proposal?.rows {
            targetHeight = max(rows, fixedHeight + minimums.reduce(0, +) + spacingHeight)
        }
        else {
            targetHeight = idealHeight
        }

        let flexibleLengths = flexibleLengths(
            count: flexibleCount,
            minimums: minimums,
            extra: targetHeight - minimums.reduce(0, +) - fixedHeight - spacingHeight
        )
        var flexibleIndex = 0
        var y = 0
        return children.compactMap { child in
            let element: RenderedElement
            let itemHeight: Int
            switch child.content {
            case .block(let block):
                if child.traits.flexibleAxes.contains(.vertical) {
                    let height = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                    element = child.render(
                        verticalChildProposal(
                            height,
                            traits: child.traits,
                            stackProposal: proposal
                        ),
                        false
                    ) ?? .block(block)
                }
                else {
                    element = child.content
                }
                itemHeight = element.verticalLength
            case .spacer:
                itemHeight = flexibleLengths[flexibleIndex]
                flexibleIndex += 1
                element = child.content
            }

            guard element.isRenderable else {
                return nil
            }

            let item = VerticalItem(content: element, y: y, height: itemHeight)
            y += item.height + max(spacing, 0)
            return item
        }
    }

    private static func measuredChildren(
        from children: [StackChild],
        proposal: RenderProposal?,
        stackAxis: Axis,
        childProposal: (Int?, LayoutTraits, RenderProposal?) -> RenderProposal
    ) -> [MeasuredChild] {
        children.compactMap { child in
            let flexibleOnStackAxis: Bool
            switch stackAxis {
            case .horizontal:
                flexibleOnStackAxis = child.traits.flexibleAxes.contains(.horizontal)
            case .vertical:
                flexibleOnStackAxis = child.traits.flexibleAxes.contains(.vertical)
            }

            guard let content = child.render(
                childProposal(nil, child.traits, proposal),
                flexibleOnStackAxis
            ), content.isRenderable else {
                return nil
            }

            return MeasuredChild(
                content: content,
                traits: child.traits,
                render: child.render
            )
        }
    }

    private static func horizontalChildProposal(
        _ width: Int?,
        traits: LayoutTraits,
        stackProposal: RenderProposal?
    ) -> RenderProposal {
        RenderProposal(
            columns: width,
            rows: traits.flexibleAxes.contains(.vertical)
                || !traits.flexibleAxes.contains(.horizontal) ? stackProposal?.rows : nil
        )
    }

    private static func verticalChildProposal(
        _ height: Int?,
        traits: LayoutTraits,
        stackProposal: RenderProposal?
    ) -> RenderProposal {
        RenderProposal(
            columns: traits.flexibleAxes.contains(.horizontal)
                || !traits.flexibleAxes.contains(.vertical) ? stackProposal?.columns : nil,
            rows: height
        )
    }

    private static func fixedHorizontalWidth(from children: [MeasuredChild]) -> Int {
        children.reduce(0) { width, child in
            switch child.content {
            case .block:
                if child.traits.flexibleAxes.contains(.horizontal) {
                    return width
                }
                return width + child.content.horizontalLength
            case .spacer:
                return width
            }
        }
    }

    private static func fixedVerticalHeight(from children: [MeasuredChild]) -> Int {
        children.reduce(0) { height, child in
            switch child.content {
            case .block:
                if child.traits.flexibleAxes.contains(.vertical) {
                    return height
                }
                return height + child.content.verticalLength
            case .spacer:
                return height
            }
        }
    }

    private static func horizontalCursor(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> RenderedCursor? {
        for item in items {
            guard let block = item.block, let cursor = block.cursor else {
                continue
            }

            return RenderedCursor(
                row: verticalOffset(
                    contentHeight: block.height,
                    containerHeight: height,
                    alignment: alignment
                ) + cursor.row,
                column: item.x + cursor.column
            )
        }

        return nil
    }

    private static func horizontalHitRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedHitRegion] {
        items.flatMap { item -> [RenderedHitRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                contentHeight: block.height,
                containerHeight: height,
                alignment: alignment
            )
            return block.hitRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalScrollRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedScrollRegion] {
        items.flatMap { item -> [RenderedScrollRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                contentHeight: block.height,
                containerHeight: height,
                alignment: alignment
            )
            return block.scrollRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalFocusRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedFocusRegion] {
        items.flatMap { item -> [RenderedFocusRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                contentHeight: block.height,
                containerHeight: height,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func verticalCursor(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> RenderedCursor? {
        for item in items {
            guard let block = item.block, let cursor = block.cursor else {
                continue
            }

            return RenderedCursor(
                row: item.y + cursor.row,
                column: horizontalOffset(
                    contentWidth: block.width,
                    containerWidth: width,
                    alignment: alignment
                ) + cursor.column
            )
        }

        return nil
    }

    private static func verticalHitRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedHitRegion] {
        items.flatMap { item -> [RenderedHitRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                contentWidth: block.width,
                containerWidth: width,
                alignment: alignment
            )
            return block.hitRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalScrollRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedScrollRegion] {
        items.flatMap { item -> [RenderedScrollRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                contentWidth: block.width,
                containerWidth: width,
                alignment: alignment
            )
            return block.scrollRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalFocusRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedFocusRegion] {
        items.flatMap { item -> [RenderedFocusRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                contentWidth: block.width,
                containerWidth: width,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func flexibleLengths(
        count: Int,
        minimums: [Int],
        extra: Int
    ) -> [Int] {
        guard count > 0 else {
            return []
        }

        let shared = extra / count
        let remainder = extra % count
        return minimums.enumerated().map { index, minimum in
            minimum + shared + (index < remainder ? 1 : 0)
        }
    }

    private static func spacingWidth(for count: Int, spacing: Int) -> Int {
        max(count - 1, 0) * max(spacing, 0)
    }

    private static func line(
        from block: RenderedBlock,
        at row: Int,
        in height: Int,
        alignedBy alignment: VerticalAlignment
    ) -> String {
        let offset = verticalOffset(
            contentHeight: block.height,
            containerHeight: height,
            alignment: alignment
        )
        let contentRange = offset..<(offset + block.height)
        guard contentRange.contains(row) else {
            return String(repeating: " ", count: block.width)
        }

        return block.lines[row - offset].padded(toWidth: block.width)
    }

    private static func line(
        _ line: String,
        alignedBy alignment: HorizontalAlignment,
        in width: Int
    ) -> String {
        let padding = max(width - TerminalText.columnWidth(line), 0)
        switch alignment {
        case .leading:
            return line + String(repeating: " ", count: padding)
        case .center:
            let leading = padding / 2
            let trailing = padding - leading
            return String(repeating: " ", count: leading)
                + line
                + String(repeating: " ", count: trailing)
        case .trailing:
            return String(repeating: " ", count: padding) + line
        }
    }

    private static func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = max(containerWidth - contentWidth, 0)
        switch alignment {
        case .leading:
            return 0
        case .center:
            return padding / 2
        case .trailing:
            return padding
        }
    }

    private static func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = max(containerHeight - contentHeight, 0)
        switch alignment {
        case .top:
            return 0
        case .center:
            return padding / 2
        case .bottom:
            return padding
        }
    }
}

private extension Array where Element == RenderedElement {

    var spacerCount: Int {
        filter(\.isSpacer).count
    }

    var spacerMinimums: [Int] {
        compactMap(\.spacerMinimum)
    }
}

private extension Array where Element == StackRenderer.MeasuredChild {

    var horizontalFlexibleCount: Int {
        filter(\.isHorizontallyFlexible).count
    }

    var verticalFlexibleCount: Int {
        filter(\.isVerticallyFlexible).count
    }

    var horizontalMinimums: [Int] {
        compactMap { child in
            child.isHorizontallyFlexible ? child.content.spacerMinimum ?? 0 : nil
        }
    }

    var verticalMinimums: [Int] {
        compactMap { child in
            child.isVerticallyFlexible ? child.content.spacerMinimum ?? 0 : nil
        }
    }
}

private extension StackRenderer.MeasuredChild {

    var isHorizontallyFlexible: Bool {
        switch content {
        case .block:
            return traits.flexibleAxes.contains(.horizontal)
        case .spacer:
            return true
        }
    }

    var isVerticallyFlexible: Bool {
        switch content {
        case .block:
            return traits.flexibleAxes.contains(.vertical)
        case .spacer:
            return true
        }
    }
}

private extension RenderedElement {

    var horizontalLength: Int {
        switch self {
        case .block(let block):
            return block.width
        case .spacer(let minLength):
            return minLength
        }
    }

    var isRenderable: Bool {
        switch self {
        case .block(let block):
            return !block.lines.isEmpty
        case .spacer:
            return true
        }
    }

    var isSpacer: Bool {
        guard case .spacer = self else {
            return false
        }

        return true
    }

    var spacerMinimum: Int? {
        guard case .spacer(let minLength) = self else {
            return nil
        }

        return minLength
    }

    var verticalLength: Int {
        switch self {
        case .block(let block):
            return block.height
        case .spacer(let minLength):
            return minLength
        }
    }
}

private extension String {

    func padded(toWidth width: Int) -> String {
        TerminalText.padded(self, toWidth: width)
    }
}
