import Foundation

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
            switch TerminalControl.readInput(timeout: inputTimeout(using: runtime)) {
            case .quit:
                return
            case .keyPress(let keyPress):
                _ = runtime.dispatch(keyPress)
            case .mouse(let mouseEvent):
                _ = runtime.dispatch(mouseEvent)
            case .none:
                break
            }

            _ = runtime.dispatchExpiredTapActions()

            if runtime.consumeInvalidation() {
                render(root, using: runtime)
            }
        }
    }

    private func render(_ root: any RootScene, using runtime: StateRuntime) {
        repeat {
            let viewport = TerminalControl.currentTerminalSize()
            guard let block = runtime.block(
                from: root.root,
                in: RenderProposal(viewport)
            ) else {
                return
            }

            runtime.updateRenderedFrame(TextRenderer.frame(for: block, in: viewport))
            render(block, in: viewport)
        } while runtime.consumeInvalidation()
    }

    private func render(_ block: RenderedBlock, in viewport: TerminalViewportSize) {
        TerminalControl.write(TextRenderer.screen(for: block, in: viewport))
    }

    private func inputTimeout(using runtime: StateRuntime) -> TimeInterval? {
        runtime.nextTapDeadline.map {
            max($0.timeIntervalSinceNow, 0)
        }
    }
}
