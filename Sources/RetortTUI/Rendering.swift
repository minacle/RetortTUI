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

struct RenderedBlock: Equatable, Sendable {

    var lines: [String]

    var cursor: RenderedCursor?

    var hitRegions: [RenderedHitRegion]

    init(
        lines: [String],
        cursor: RenderedCursor? = nil,
        hitRegions: [RenderedHitRegion] = []
    ) {
        self.lines = lines
        self.cursor = cursor
        self.hitRegions = hitRegions
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
        block(from: view, in: proposal, path: [], runtime: nil)
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
                group.elements.enumerated().compactMap { index, element in
                    element.renderedElement(
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

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any FrameModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
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

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let modifier = view as? any FrameModifierRenderable {
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
            ViewResolver.elements(
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
            ViewResolver.elements(
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
            return group.elements.compactMap { $0.renderedBlock() }
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
            return group.elements.enumerated().compactMap { index, element in
                element.renderedElement(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        return element(
            from: view,
            in: proposal,
            path: path,
            runtime: runtime
        ).map { [$0] } ?? []
    }
}

enum StackRenderer {

    static func horizontal(
        _ elements: [RenderedElement],
        alignment: VerticalAlignment,
        spacing: Int,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        let items = horizontalItems(from: elements, spacing: spacing, proposal: proposal)
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
            hitRegions: horizontalHitRegions(from: items, height: height, alignment: alignment)
        )
    }

    static func vertical(
        _ elements: [RenderedElement],
        alignment: HorizontalAlignment,
        spacing: Int,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        let items = verticalItems(from: elements, spacing: spacing, proposal: proposal)
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
            hitRegions: verticalHitRegions(from: items, width: width, alignment: alignment)
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

    private static func horizontalItems(
        from elements: [RenderedElement],
        spacing: Int,
        proposal: RenderProposal?
    ) -> [HorizontalItem] {
        let elements = elements.filter(\.isRenderable)
        let spacerCount = elements.spacerCount
        let idealWidth = elements.reduce(0) { width, element in
            width + element.horizontalLength
        } + spacingWidth(for: elements.count, spacing: spacing)
        let targetWidth: Int
        if spacerCount > 0, let columns = proposal?.columns {
            targetWidth = max(columns, idealWidth)
        }
        else {
            targetWidth = idealWidth
        }

        let spacerLengths = flexibleLengths(
            count: spacerCount,
            minimums: elements.spacerMinimums,
            extra: targetWidth - idealWidth
        )
        var spacerIndex = 0
        var x = 0
        return elements.map { element in
            switch element {
            case .block(let block):
                let item = HorizontalItem(content: element, x: x, width: block.width)
                x += block.width + max(spacing, 0)
                return item
            case .spacer:
                let width = spacerLengths[spacerIndex]
                spacerIndex += 1
                let item = HorizontalItem(content: element, x: x, width: width)
                x += width + max(spacing, 0)
                return item
            }
        }
    }

    private static func verticalItems(
        from elements: [RenderedElement],
        spacing: Int,
        proposal: RenderProposal?
    ) -> [VerticalItem] {
        let elements = elements.filter(\.isRenderable)
        let spacerCount = elements.spacerCount
        let idealHeight = elements.reduce(0) { height, element in
            height + element.verticalLength
        } + spacingWidth(for: elements.count, spacing: spacing)
        let targetHeight: Int
        if spacerCount > 0, let rows = proposal?.rows {
            targetHeight = max(rows, idealHeight)
        }
        else {
            targetHeight = idealHeight
        }

        let spacerLengths = flexibleLengths(
            count: spacerCount,
            minimums: elements.spacerMinimums,
            extra: targetHeight - idealHeight
        )
        var spacerIndex = 0
        var y = 0
        return elements.map { element in
            switch element {
            case .block(let block):
                let item = VerticalItem(content: element, y: y, height: block.height)
                y += block.height + max(spacing, 0)
                return item
            case .spacer:
                let height = spacerLengths[spacerIndex]
                spacerIndex += 1
                let item = VerticalItem(content: element, y: y, height: height)
                y += height + max(spacing, 0)
                return item
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
