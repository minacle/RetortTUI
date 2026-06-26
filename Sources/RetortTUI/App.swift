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
        guard let root = SceneResolver.rootScene(from: app.body) else {
            return
        }

        let runtime = StateRuntime()
        let termination = TerminationController()

        let session = try TerminalSession()
        try session.start()
        defer {
            session.stop()
        }

        render(root, using: runtime, termination: termination)

        while true {
            switch TerminalControl.readInput(timeout: inputTimeout(using: runtime)) {
            case .quit:
                runtime.dispatchTerminate()
            case .keyPress(let keyPress):
                _ = runtime.dispatch(keyPress)
            case .mouse(let mouseEvent):
                _ = runtime.dispatch(mouseEvent)
            case .none:
                break
            }

            _ = runtime.dispatchExpiredTapActions()

            if runtime.consumeInvalidation() {
                render(root, using: runtime, termination: termination)
            }

            if termination.isRequested {
                return
            }
        }
    }

    private func render(
        _ root: any RootScene,
        using runtime: StateRuntime,
        termination: TerminationController
    ) {
        repeat {
            let viewport = TerminalControl.currentTerminalSize()
            guard let block = root.renderedBlock(
                in: RenderProposal(viewport),
                using: runtime,
                termination: termination
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

private extension RootScene {

    func renderedBlock(
        in proposal: RenderProposal,
        using runtime: StateRuntime,
        termination: TerminationController
    ) -> RenderedBlock? {
        let action = termination.action
        return runtime.block(
            from: root
                .onTerminate {
                    action()
                }
                .environment(\.terminate, action),
            in: proposal
        )
    }
}

final class TerminationController {

    private(set) var isRequested = false

    lazy var action = TerminateAction {
        [weak self] in

        self?.isRequested = true
    }
}
