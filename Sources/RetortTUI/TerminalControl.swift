import Foundation
import Terminal
import Termios

#if os(Linux)
import Glibc
import SystemPackage
#else
import Darwin
import System
#endif

enum TerminalInput: Equatable, Sendable {

    case quit

    case none
}

enum TerminalControl {

    static let quitByte: UInt8 = 3

    static let clearScreenSequence = "\u{001B}[2J"

    static let hideCursorSequence = "\u{001B}[?25l"

    static let showCursorSequence = "\u{001B}[?25h"

    static let enterAlternateScreenSequence = "\u{001B}[?1049h"

    static let exitAlternateScreenSequence = "\u{001B}[?1049l"

    static func cursorPositionSequence(row: Int, column: Int) -> String {
        "\u{001B}[\(max(row, 1));\(max(column, 1))H"
    }

    static func currentTerminalSize() -> TerminalViewportSize {
        guard let size = try? Terminal.size(for: .standardOutput),
              size.columns > 0,
              size.rows > 0 else {
            return TerminalViewportSize(columns: 80, rows: 24)
        }

        return TerminalViewportSize(columns: size.columns, rows: size.rows)
    }

    static func readInput() -> TerminalInput {
        input(for: readByte())
    }

    static func input(for byte: UInt8) -> TerminalInput {
        switch byte {
        case quitByte:
            return .quit
        default:
            return .none
        }
    }

    static func write(_ output: String) {
        FileHandle.standardOutput.write(Data(output.utf8))
    }

    private static func readByte() -> UInt8 {
        FileHandle.standardInput.readData(ofLength: 1).first ?? 0
    }
}

final class TerminalSession {

    private let original: Termios

    private let raw: Termios

    private var isActive = false

    init() throws {
        let original = try Termios(readingFrom: .standardInput)
        var raw = original
        raw.makeRaw()
        self.original = original
        self.raw = raw
    }

    func start() throws {
        guard !isActive else {
            return
        }

        try raw.apply(to: .standardInput, when: .now)
        TerminalControl.write(TerminalControl.enterAlternateScreenSequence)
        TerminalControl.write(TerminalControl.hideCursorSequence)
        isActive = true
    }

    func stop() {
        guard isActive else {
            return
        }

        try? original.apply(to: .standardInput, when: .now)
        TerminalControl.write(TerminalControl.showCursorSequence)
        TerminalControl.write(TerminalControl.exitAlternateScreenSequence)
        isActive = false
    }
}
