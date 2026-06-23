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

        let runtime = StateRuntime()

        let session = try TerminalSession()
        try session.start()
        defer {
            session.stop()
        }

        render(root, using: runtime)

        while true {
            switch TerminalControl.readInput() {
            case .quit:
                return
            case .keyPress(let keyPress):
                _ = runtime.dispatch(keyPress)
            case .none:
                break
            }

            if runtime.consumeInvalidation() {
                render(root, using: runtime)
            }
        }
    }

    private func render(_ root: any RootScene, using runtime: StateRuntime) {
        let viewport = TerminalControl.currentTerminalSize()
        guard let block = runtime.block(
            from: root.root,
            in: RenderProposal(viewport)
        ) else {
            return
        }

        render(block, in: viewport)
    }

    private func render(_ block: RenderedBlock, in viewport: TerminalViewportSize) {
        TerminalControl.write(TextRenderer.screen(for: block, in: viewport))
    }
}
