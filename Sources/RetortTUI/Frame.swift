/// A transparent modifier that proposes a fixed terminal size to its content.
struct FrameView<Content: View>: View, FrameModifierRenderable {

    typealias Body = Never

    let content: Content

    let width: Int?

    let height: Int?

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let block = ViewResolver.block(
            from: content,
            in: frameProposal(from: proposal),
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        return frame(block, in: proposal)
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }

    private func frameProposal(from proposal: RenderProposal?) -> RenderProposal {
        RenderProposal(
            columns: width ?? proposal?.columns,
            rows: height ?? proposal?.rows
        )
    }

    private func frame(_ block: RenderedBlock, in proposal: RenderProposal?) -> RenderedBlock {
        let targetWidth = width ?? proposal?.columns ?? block.width
        let targetHeight = height ?? proposal?.rows ?? block.height
        guard targetWidth > 0, targetHeight > 0 else {
            return RenderedBlock(lines: [])
        }

        let blankLine = String(repeating: " ", count: targetWidth)
        let lines = (0..<targetHeight).map { row -> String in
            guard row < block.lines.count else {
                return blankLine
            }

            return TerminalText.slice(block.lines[row], fromColumn: 0, width: targetWidth)
        }

        return RenderedBlock(
            lines: lines,
            cursor: frameCursor(block.cursor, width: targetWidth, height: targetHeight)
        )
    }

    private func frameCursor(
        _ cursor: RenderedCursor?,
        width: Int,
        height: Int
    ) -> RenderedCursor? {
        guard let cursor,
              cursor.row >= 0,
              cursor.row < height,
              cursor.column >= 0,
              cursor.column <= width else {
            return nil
        }

        return RenderedCursor(
            row: cursor.row,
            column: min(cursor.column, width - 1)
        )
    }
}

protocol FrameModifierRenderable {

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

    /// Proposes a fixed terminal size to this view.
    func frame(width: Int? = nil, height: Int? = nil) -> some View {
        FrameView(
            content: self,
            width: width.map { max($0, 0) },
            height: height.map { max($0, 0) }
        )
    }
}
