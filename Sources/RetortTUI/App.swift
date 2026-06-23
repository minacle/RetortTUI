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
        guard let root = app.body as? any RootScene,
              let text = ViewResolver.text(from: root.root) else {
            return
        }

        let session = try TerminalSession()
        try session.start()
        defer {
            session.stop()
        }

        render(text)

        while TerminalControl.readInput() != .quit {}
    }

    private func render(_ text: String) {
        let viewport = TerminalControl.currentTerminalSize()
        TerminalControl.write(TextRenderer.screen(for: text, in: viewport))
    }
}
