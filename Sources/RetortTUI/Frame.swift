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

            return block.lines[row].slice(from: 0, length: targetWidth)
        }

        return RenderedBlock(lines: lines)
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

private extension String {

    func slice(from offset: Int, length: Int) -> String {
        let start = index(startIndex, offsetBy: min(offset, count))
        let end = index(start, offsetBy: min(length, distance(from: start, to: endIndex)))
        let slice = String(self[start..<end])
        return slice + String(repeating: " ", count: max(length - slice.count, 0))
    }
}
