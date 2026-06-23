/// A view that displays one line of text in the terminal.
public struct Text: View, Equatable, Sendable {

    public typealias Body = Never

    public let content: String

    public init(_ content: String) {
        self.content = content
    }
}
