/// A top-level description of terminal content.
public protocol Scene {}

protocol RootScene: Scene {

    associatedtype Root: View

    var root: Root { get }
}

/// The single terminal window used by a RetortTUI app.
public struct WindowGroup<Content: View>: RootScene {

    let root: Content

    public init(@ViewBuilder content: () -> Content) {
        self.root = content()
    }
}

/// A result builder for app scenes.
@resultBuilder
public enum SceneBuilder {

    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }
}
