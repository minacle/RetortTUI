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

    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildExpression<Content: View>(_ expression: Content) -> Content {
        expression
    }
}

/// A view with no visible terminal output.
public struct EmptyView: View {

    public typealias Body = Never

    public init() {}
}
