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

    case keyPress(KeyPress)

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
        let firstByte = readByte()
        var bytes = [firstByte]

        if firstByte == 27 {
            bytes.append(contentsOf: readPendingBytes(afterDelay: 10_000))
        }
        else {
            bytes.append(contentsOf: readUTF8ContinuationBytes(after: firstByte))
        }

        return input(for: bytes)
    }

    static func input(for byte: UInt8) -> TerminalInput {
        input(for: [byte])
    }

    static func input(for bytes: [UInt8]) -> TerminalInput {
        guard !bytes.isEmpty else {
            return .none
        }

        if bytes == [quitByte] {
            return .quit
        }

        if let keyPress = escapeSequenceInput(for: bytes) {
            return .keyPress(keyPress)
        }

        if bytes.count == 1,
           let keyPress = asciiInput(for: bytes[0]) {
            return .keyPress(keyPress)
        }

        if let string = String(bytes: bytes, encoding: .utf8),
           string.count == 1,
           let character = string.first {
            return .keyPress(
                KeyPress(
                    key: KeyEquivalent(character),
                    characters: string
                )
            )
        }

        return .none
    }

    static func write(_ output: String) {
        FileHandle.standardOutput.write(Data(output.utf8))
    }

    private static func readByte() -> UInt8 {
        FileHandle.standardInput.readData(ofLength: 1).first ?? 0
    }

    private static func readUTF8ContinuationBytes(after firstByte: UInt8) -> [UInt8] {
        let count: Int
        switch firstByte {
        case 0b1100_0000...0b1101_1111:
            count = 1
        case 0b1110_0000...0b1110_1111:
            count = 2
        case 0b1111_0000...0b1111_0111:
            count = 3
        default:
            count = 0
        }

        guard count > 0 else {
            return []
        }

        return Array(FileHandle.standardInput.readData(ofLength: count))
    }

    private static func readPendingBytes(afterDelay delay: useconds_t) -> [UInt8] {
        usleep(delay)

        let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
        guard flags >= 0 else {
            return []
        }

        _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
        defer {
            _ = fcntl(STDIN_FILENO, F_SETFL, flags)
        }

        var bytes: [UInt8] = []
        var byte: UInt8 = 0

        while bytes.count < 16, readNonblockingByte(into: &byte) == 1 {
            bytes.append(byte)
        }

        return bytes
    }

    private static func readNonblockingByte(into byte: inout UInt8) -> Int {
        #if os(Linux)
        Glibc.read(STDIN_FILENO, &byte, 1)
        #else
        Darwin.read(STDIN_FILENO, &byte, 1)
        #endif
    }

    private static func escapeSequenceInput(for bytes: [UInt8]) -> KeyPress? {
        switch bytes {
        case [27]:
            return keyPress(for: .escape)
        case [27, 91, 65]:
            return keyPress(for: .upArrow)
        case [27, 91, 66]:
            return keyPress(for: .downArrow)
        case [27, 91, 67]:
            return keyPress(for: .rightArrow)
        case [27, 91, 68]:
            return keyPress(for: .leftArrow)
        case [27, 91, 72], [27, 79, 72], [27, 91, 49, 126], [27, 91, 55, 126]:
            return keyPress(for: .home)
        case [27, 91, 70], [27, 79, 70], [27, 91, 52, 126], [27, 91, 56, 126]:
            return keyPress(for: .end)
        case [27, 91, 53, 126]:
            return keyPress(for: .pageUp)
        case [27, 91, 54, 126]:
            return keyPress(for: .pageDown)
        case [27, 91, 51, 126]:
            return keyPress(for: .deleteForward)
        default:
            return nil
        }
    }

    private static func asciiInput(for byte: UInt8) -> KeyPress? {
        switch byte {
        case 8, 127:
            return keyPress(for: .delete)
        case 9:
            return keyPress(for: .tab)
        case 10, 13:
            return keyPress(for: .return)
        case 27:
            return keyPress(for: .escape)
        case 32:
            return keyPress(for: .space)
        case 1...7, 11...12, 14...26:
            let scalar = UnicodeScalar(byte + 96)
            let character = Character(scalar)
            return KeyPress(
                key: KeyEquivalent(character),
                characters: String(character),
                modifiers: .control
            )
        case 33...126:
            let scalar = UnicodeScalar(byte)
            let character = Character(scalar)
            return KeyPress(
                key: KeyEquivalent(character),
                characters: String(character)
            )
        default:
            return nil
        }
    }

    private static func keyPress(for key: KeyEquivalent) -> KeyPress {
        KeyPress(
            key: key,
            characters: String(key.character)
        )
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
