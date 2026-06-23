/// The entry point for a RetortTUI application.
public protocol App {

    associatedtype Body: Scene

    @SceneBuilder
    var body: Body { get }

    init()
}

public extension App {

    static func main() {
        do {
            try AppRunner(app: Self()).run()
        } catch {
            TerminalControl.write("RetortTUI failed to start: \(error)\n")
        }
    }
}

struct AppRunner<Application: App> {

    var app: Application

    func run() throws {
        guard let root = app.body as? any RootScene else {
            return
        }

        let viewport = TerminalControl.currentTerminalSize()
        guard let block = ViewResolver.block(
            from: root.root,
            in: RenderProposal(viewport)
        ) else {
            return
        }

        let session = try TerminalSession()
        try session.start()
        defer {
            session.stop()
        }

        render(block, in: viewport)

        while TerminalControl.readInput() != .quit {}
    }

    private func render(_ block: RenderedBlock, in viewport: TerminalViewportSize) {
        TerminalControl.write(TextRenderer.screen(for: block, in: viewport))
    }
}
