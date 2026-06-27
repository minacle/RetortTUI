import Foundation

/// A view that displays text in the terminal.
public struct Text: View, Equatable, Sendable {

    public typealias Body = Never

    public let content: String

    public init(_ content: String) {
        self.content = content
    }
}

struct TextLineLimit: Equatable, Sendable {

    let number: Int?

    let reservesSpace: Bool
}

struct LineLimitView<Content: View>: View, LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let lineLimit: TextLineLimit

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        TextLineLimitContext.withLineLimit(lineLimit) {
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
        TextLineLimitContext.withLineLimit(lineLimit) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

public extension View {

    /// Limits the number of lines used to render text within this view.
    func lineLimit(_ number: Int?) -> some View {
        lineLimit(number, reservesSpace: false)
    }

    /// Limits the number of lines used to render text within this view.
    func lineLimit(_ number: Int?, reservesSpace: Bool) -> some View {
        if let number {
            precondition(number >= 1, "lineLimit must be greater than zero.")
        }

        return LineLimitView(
            content: self,
            lineLimit: TextLineLimit(number: number, reservesSpace: reservesSpace)
        )
    }
}

enum TextLineLimitContext {

    private static let threadKey = "RetortTUI.TextLineLimitContext"

    static var current: TextLineLimit {
        get {
            Thread.current.threadDictionary[threadKey] as? TextLineLimit
                ?? TextLineLimit(number: nil, reservesSpace: false)
        }
        set {
            Thread.current.threadDictionary[threadKey] = newValue
        }
    }

    static func withLineLimit<Value>(
        _ lineLimit: TextLineLimit,
        perform operation: () -> Value
    ) -> Value {
        let previous = current
        current = lineLimit
        defer {
            current = previous
        }

        return operation()
    }
}
