/// A type that represents a terminal user interface fragment.
public protocol View {

    associatedtype Body: View = Never

    @ViewBuilder
    var body: Body { get }
}

public extension View where Body == Never {

    var body: Never {
        fatalError("Primitive RetortTUI views do not have a body.")
    }
}

extension Never: View {

    public var body: Never {
        fatalError("Never has no body.")
    }
}

/// A result builder for RetortTUI view content.
@resultBuilder
public enum ViewBuilder {

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildPartialBlock<Content: View>(first content: Content) -> Content {
        content
    }

    public static func buildPartialBlock<Accumulated: View, Content: View>(
        accumulated: Accumulated,
        next content: Content
    ) -> some View {
        ViewGroup(elements(from: accumulated) + [AnyViewStorage(content)])
    }

    public static func buildExpression<Content: View>(_ expression: Content) -> Content {
        expression
    }

    private static func elements<Content: View>(from content: Content) -> [AnyViewStorage] {
        if let group = content as? ViewGroup {
            return group.elements
        }

        return [AnyViewStorage(content)]
    }
}

/// A view with no visible terminal output.
public struct EmptyView: View {

    public typealias Body = Never

    public init() {}
}

struct ViewGroup: View {

    typealias Body = Never

    let elements: [AnyViewStorage]

    init(_ elements: [AnyViewStorage]) {
        self.elements = elements
    }
}

struct AnyViewStorage {

    private let element: (RenderProposal?, [Int], StateRuntime?) -> RenderedElement?

    init<Content: View>(_ content: Content) {
        self.element = { proposal, path, runtime in
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    func renderedElement(in proposal: RenderProposal? = nil) -> RenderedElement? {
        renderedElement(in: proposal, path: [], runtime: nil)
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        element(proposal, path, runtime)
    }

    func renderedBlock() -> RenderedBlock? {
        renderedBlock(in: nil)
    }

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        guard case .block(let block) = renderedElement(in: proposal) else {
            return nil
        }

        return block
    }
}
