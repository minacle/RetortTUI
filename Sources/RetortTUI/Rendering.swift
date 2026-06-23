import Foundation

struct TerminalViewportSize: Equatable, Sendable {

    var columns: Int

    var rows: Int

    init(columns: Int, rows: Int) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
    }
}

struct TextFrame: Equatable, Sendable {

    var text: String

    var row: Int

    var column: Int
}

enum ViewResolver {

    static func text<Content: View>(from view: Content) -> String? {
        if let text = view as? Text {
            return text.content
        }

        if view is EmptyView {
            return nil
        }

        return text(from: view.body)
    }
}

enum TextRenderer {

    static func frame(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> TextFrame {
        let row = max((viewport.rows + 1) / 2, 1)
        let column = max(((viewport.columns - text.count) / 2) + 1, 1)
        return TextFrame(text: text, row: row, column: column)
    }

    static func screen(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> String {
        let frame = frame(for: text, in: viewport)
        return TerminalControl.clearScreenSequence
            + TerminalControl.cursorPositionSequence(row: frame.row, column: frame.column)
            + frame.text
    }
}
