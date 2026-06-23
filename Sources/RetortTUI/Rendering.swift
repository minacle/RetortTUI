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

struct RenderedBlock: Equatable, Sendable {

    var lines: [String]

    var text: String {
        lines.joined(separator: "\n")
    }

    var width: Int {
        lines.map(\.count).max() ?? 0
    }

    var height: Int {
        lines.count
    }
}

enum ViewResolver {

    static func text<Content: View>(from view: Content) -> String? {
        block(from: view)?.text
    }

    static func block<Content: View>(from view: Content) -> RenderedBlock? {
        if let text = view as? Text {
            return RenderedBlock(lines: [text.content])
        }

        if view is EmptyView {
            return nil
        }

        if let group = view as? ViewGroup {
            return StackRenderer.vertical(
                group.elements.compactMap { $0.renderedBlock() },
                alignment: .leading,
                spacing: 0
            )
        }

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock()
        }

        return block(from: view.body)
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
                TerminalControl.cursorPositionSequence(
                    row: frame.row + offset,
                    column: frame.column
                ) + line
            }.joined()
    }
}

protocol StackRenderable {

    func renderedBlock() -> RenderedBlock?
}

extension HStack: StackRenderable {

    func renderedBlock() -> RenderedBlock? {
        StackRenderer.horizontal(
            ViewResolver.blocks(from: content),
            alignment: alignment,
            spacing: spacing
        )
    }
}

extension VStack: StackRenderable {

    func renderedBlock() -> RenderedBlock? {
        StackRenderer.vertical(
            ViewResolver.blocks(from: content),
            alignment: alignment,
            spacing: spacing
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
}

enum StackRenderer {

    static func horizontal(
        _ blocks: [RenderedBlock],
        alignment: VerticalAlignment,
        spacing: Int
    ) -> RenderedBlock? {
        let blocks = blocks.filter { !$0.lines.isEmpty }
        guard !blocks.isEmpty else {
            return nil
        }

        let height = blocks.map(\.height).max() ?? 0
        let gap = String(repeating: " ", count: max(spacing, 0))
        let lines = (0..<height).map { row in
            blocks.map { block in
                line(from: block, at: row, in: height, alignedBy: alignment)
            }.joined(separator: gap)
        }

        return RenderedBlock(lines: lines)
    }

    static func vertical(
        _ blocks: [RenderedBlock],
        alignment: HorizontalAlignment,
        spacing: Int
    ) -> RenderedBlock? {
        let blocks = blocks.filter { !$0.lines.isEmpty }
        guard !blocks.isEmpty else {
            return nil
        }

        let width = blocks.map(\.width).max() ?? 0
        let gap = Array(repeating: "", count: max(spacing, 0))
        let lines = blocks.enumerated().flatMap { index, block in
            let lines = block.lines.map {
                line($0, alignedBy: alignment, in: width)
            }

            if index == blocks.indices.last {
                return lines
            }

            return lines + gap
        }

        return RenderedBlock(lines: lines)
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
        let padding = max(width - line.count, 0)
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

private extension String {

    func padded(toWidth width: Int) -> String {
        self + String(repeating: " ", count: max(width - count, 0))
    }
}
