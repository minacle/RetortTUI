import Foundation
import Testing
@testable import SwiftTUI
import RetortTUI

@Test func retortTUIReexportsSwiftTUITextAPI() {
    let text = Text("Hello")

    #expect(text.content == "Hello")
}

@Test func retortTUIReexportsSwiftTUIStateAPI() {
    var value = "initial"
    let binding = Binding(
        get: {
            value
        },
        set: { newValue in
            value = newValue
        }
    )

    binding.wrappedValue = "updated"

    #expect(value == "updated")
}

@Test func retortTUIReexportsSwiftTUIViewBuilderAPI() {
    let view = SmokeView()

    #expect(view.title.content == "Smoke")
}

private struct SmokeView: View {

    var title: Text {
        Text("Smoke")
    }

    var body: some View {
        VStack(alignment: .leading) {
            title
            Text("Visible through RetortTUI")
                .color(.brightCyan)
                .bold()
        }
    }
}

private enum RuntimeListID: Hashable {

    case group

    case child

    case editor

    case integerEditor

    case customEditor

    case choice

    case action

    case reset

    case item(Int)
}

private enum RuntimeChoice: String, CaseIterable {

    case development

    case production
}

@Test func retortListPublicRowAPIsRenderThroughList() {
    let runtime = StateRuntime()
    let view = RetortListPublicAPIRuntimeView()
    let proposal = RenderProposal(columns: 48, rows: 4)
    let block = runtime.block(from: view, in: proposal)

    #expect(block?.lines.first?.hasPrefix("❯   ● Runtime title  subtitle") == true)
    #expect(block?.lines.contains { $0.contains("String title  value") } == true)
    #expect(block?.runs.contains {
        $0.text == "●" && $0.style == TextStyle(color: .green, isBold: false)
    } == true)
}

@Test func retortListItemBuilderRendersConditionalsAndArrays() {
    let runtime = StateRuntime()
    let view = RetortListBuilderRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)
    let block = runtime.block(from: view, in: proposal)

    let visibleLines = block?.lines
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    #expect(visibleLines == [
        "❯   Child",
        "Action",
        "Resettable",
    ])
}

@Test func retortListRuntimeCollapsesAndExpandsTreeRows() {
    let runtime = StateRuntime()
    let view = RetortListTreeRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▾ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == true)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▸ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == false)

    #expect(runtime.dispatch(KeyPress(key: .space, characters: " ")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▾ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == true)
}

@Test func retortListKeyboardNavigationMovesRenderedSelection() {
    let runtime = StateRuntime()
    let view = RetortListNavigationRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)

    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯   Item 1") } == true)

    #expect(runtime.dispatch(KeyPress(key: .end, characters: "\u{F72B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯   Item 7") } == true)

    #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯   Item 6") } == true)

    #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯   Item 0") } == true)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯   Item 4") } == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯   Item 0") } == true)
}

@Test func retortListTextEditorShowsRealCursorAndEditsAfterReturn() {
    let runtime = StateRuntime()
    let view = RetortListTextEditorRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    let editorBlock = runtime.block(from: view, in: proposal)
    #expect(editorBlock?.cursor != nil)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())

    let editedBlock = runtime.block(from: view, in: proposal)
    #expect(editedBlock?.lines.contains { $0.contains("a") } == true)
    #expect(editedBlock?.cursor != nil)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    let committedBlock = runtime.block(from: view, in: proposal)
    #expect(committedBlock?.lines.first?.contains("a") == true)

    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())

    let movedBlock = runtime.block(from: view, in: proposal)
    #expect(movedBlock?.lines.contains { $0.hasPrefix("❯   Item 0") } == true)
}

@Test func retortListTextEditorReturnsFocusToRowAfterEscape() {
    let runtime = StateRuntime()
    let view = RetortListTextEditorRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())

    let movedBlock = runtime.block(from: view, in: proposal)
    #expect(movedBlock?.lines.contains { $0.hasPrefix("❯   Item 0") } == true)
}

@Test func retortListTextEditorEscapeAfterRejectedCommitKeepsOriginalValue() {
    let runtime = StateRuntime()
    let view = RetortListRejectingTextEditorRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    for _ in 0..<5 {
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    }
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    let rejectedBlock = runtime.block(from: view, in: proposal)
    #expect(rejectedBlock?.lines.contains { $0.contains("Error: required") } == true)

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())

    let cancelledBlock = runtime.block(from: view, in: proposal)
    #expect(cancelledBlock?.lines.first?.contains("valid") == true)
    #expect(cancelledBlock?.lines.contains { $0.contains("Error: required") } == false)
}

@Test func retortListIntegerEditorCommitsParsedValuesAndRejectsParseFailures() {
    let runtime = StateRuntime()
    let view = RetortListIntegerEditorRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: "4", characters: "4")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "2", characters: "2")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.first?.contains("142") == true)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: "x", characters: "x")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("Error: enter a valid integer") } == true)

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.first?.contains("142") == true)
}

@Test func retortListCustomEditorUsesTextAndParseClosures() {
    let runtime = StateRuntime()
    let view = RetortListCustomEditorRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    for _ in "development" {
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    }
    for character in "production" {
        #expect(runtime.dispatch(KeyPress(key: KeyEquivalent(character), characters: String(character))) == .handled)
    }
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.first?.contains("production") == true)

    let invalidRuntime = StateRuntime()
    let invalidView = RetortListCustomEditorRuntimeView()

    _ = invalidRuntime.block(from: invalidView, in: proposal)
    _ = invalidRuntime.consumeInvalidation()
    _ = invalidRuntime.block(from: invalidView, in: proposal)

    #expect(invalidRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(invalidRuntime.consumeInvalidation())
    _ = invalidRuntime.block(from: invalidView, in: proposal)

    for _ in "development" {
        #expect(invalidRuntime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    }
    #expect(invalidRuntime.consumeInvalidation())
    _ = invalidRuntime.block(from: invalidView, in: proposal)

    #expect(invalidRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(invalidRuntime.consumeInvalidation())

    _ = invalidRuntime.block(from: invalidView, in: proposal)

    #expect(invalidRuntime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(invalidRuntime.consumeInvalidation())

    block = invalidRuntime.block(from: invalidView, in: proposal)
    #expect(block?.lines.first?.contains("development") == true)
}

@Test func retortListChoiceEditorMovesCommitsAndKeepsRejectedValues() {
    let acceptedRuntime = StateRuntime()
    let acceptedView = RetortListChoiceEditorRuntimeView(rejectProduction: false)
    let proposal = RenderProposal(columns: 40, rows: 5)

    _ = acceptedRuntime.block(from: acceptedView, in: proposal)
    _ = acceptedRuntime.consumeInvalidation()
    _ = acceptedRuntime.block(from: acceptedView, in: proposal)

    #expect(acceptedRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(acceptedRuntime.consumeInvalidation())
    _ = acceptedRuntime.block(from: acceptedView, in: proposal)

    #expect(acceptedRuntime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(acceptedRuntime.consumeInvalidation())
    _ = acceptedRuntime.block(from: acceptedView, in: proposal)

    #expect(acceptedRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(acceptedRuntime.consumeInvalidation())

    let acceptedBlock = acceptedRuntime.block(from: acceptedView, in: proposal)
    #expect(acceptedBlock?.lines.first?.contains("production") == true)

    let rejectedRuntime = StateRuntime()
    let rejectedView = RetortListChoiceEditorRuntimeView(rejectProduction: true)

    _ = rejectedRuntime.block(from: rejectedView, in: proposal)
    _ = rejectedRuntime.consumeInvalidation()
    _ = rejectedRuntime.block(from: rejectedView, in: proposal)

    #expect(rejectedRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(rejectedRuntime.consumeInvalidation())
    _ = rejectedRuntime.block(from: rejectedView, in: proposal)

    #expect(rejectedRuntime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(rejectedRuntime.consumeInvalidation())
    _ = rejectedRuntime.block(from: rejectedView, in: proposal)

    #expect(rejectedRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(rejectedRuntime.consumeInvalidation())
    _ = rejectedRuntime.block(from: rejectedView, in: proposal)

    #expect(rejectedRuntime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(rejectedRuntime.consumeInvalidation())

    let rejectedBlock = rejectedRuntime.block(from: rejectedView, in: proposal)
    #expect(rejectedBlock?.lines.first?.contains("development") == true)
}

@Test func retortListKeepsKeyboardSelectionVisibleInsideOwnScrollView() {
    let runtime = StateRuntime()
    let view = RetortListScrollRuntimeView()
    let proposal = RenderProposal(columns: 24, rows: 4)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    for _ in 0..<6 {
        #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: proposal)
    }

    let block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("Item 6") } == true)
}

@Test func retortListBindingActionMutatesParentState() {
    let runtime = StateRuntime()
    let view = RetortListBindingActionRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 3)

    #expect(runtime.block(from: view, in: proposal)?.lines.first?.contains("idle") == true)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    #expect(runtime.block(from: view, in: proposal)?.lines.first?.contains("ran") == true)
}

@Test func retortListBindingResetMutatesParentState() {
    let runtime = StateRuntime()
    let view = RetortListBindingResetRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 3)

    #expect(runtime.block(from: view, in: proposal)?.lines.first?.contains("ran") == true)

    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())

    #expect(runtime.block(from: view, in: proposal)?.lines.first?.contains("idle") == true)
}

private struct RetortListPublicAPIRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    @State
    private var value = "value"

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .item(0)) {
                Text("Runtime title")
            }
            .subtitle {
                Text("subtitle")
            }
            .leadingAccessory {
                Text("●").color(.green)
            }
            .onActivate {}

            RetortListItem(id: .editor, title: "String title")
                .editor($value)

            RetortListItem(id: .reset, title: "Reset row")
                .onReset($value) {
                    $0 = "reset"
                }
        }
        .frame(width: 48, height: 4, alignment: .leading)
    }
}

private struct RetortListBuilderRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .child

    private let includeChild = true

    private let ids: [RuntimeListID] = [
        .action,
        .reset,
    ]

    var body: some View {
        RetortList(selection: $selection) {
            if includeChild {
                RetortListItem(id: .child, title: "Child")
            }

            for id in ids {
                RetortListItem(
                    id: id,
                    title: id == .action ? "Action" : "Resettable"
                )
            }
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListTreeRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .group

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, title: "Group") {
                RetortListItem(id: .child, title: "Child")
            }
            RetortListItem(id: .item(0), title: "Item 0")
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListNavigationRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    var body: some View {
        RetortList(selection: $selection) {
            for index in 0..<8 {
                RetortListItem(id: .item(index), title: "Item \(index)")
            }
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListTextEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .editor

    @State
    private var value = ""

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .editor,
                title: "Editor"
            )
            .editor(
                $value,
                validate: {
                    guard !$0.isEmpty else {
                        return .rejected("required")
                    }

                    return .accepted
                }
            )

            for index in 0..<8 {
                RetortListItem(id: .item(index), title: "Item \(index)")
            }
        }
        .frame(width: 32, height: 5, alignment: .leading)
    }
}

private struct RetortListRejectingTextEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .editor

    @State
    private var value = "valid"

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .editor,
                title: "Editor"
            )
            .editor(
                $value,
                validate: {
                    guard !$0.isEmpty else {
                        return .rejected("required")
                    }

                    return .accepted
                }
            )

            for index in 0..<8 {
                RetortListItem(id: .item(index), title: "Item \(index)")
            }
        }
        .frame(width: 32, height: 5, alignment: .leading)
    }
}

private struct RetortListIntegerEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .integerEditor

    @State
    private var value = 1

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .integerEditor,
                title: "Integer"
            )
            .editor(
                $value,
                invalidMessage: "enter a valid integer"
            )
        }
        .frame(width: 40, height: 5, alignment: .leading)
    }
}

private struct RetortListCustomEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .customEditor

    @State
    private var value = "development"

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .customEditor,
                title: "Custom"
            )
            .editor(
                $value,
                text: { $0 },
                parse: {
                    ["development", "production"].contains($0) ? $0 : nil
                },
                invalidMessage: "choose development or production"
            )
        }
        .frame(width: 40, height: 5, alignment: .leading)
    }
}

private struct RetortListChoiceEditorRuntimeView: View {

    let rejectProduction: Bool

    @FocusState
    private var selection: RuntimeListID? = .choice

    @State
    private var value = RuntimeChoice.development

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .choice,
                title: "Choice"
            )
            .choices(
                $value,
                from: RuntimeChoice.allCases,
                name: \.rawValue,
                validate: {
                    if rejectProduction && $0 == .production {
                        return .rejected("not allowed")
                    }

                    return .accepted
                }
            )
        }
        .frame(width: 40, height: 5, alignment: .leading)
    }
}

private struct RetortListBindingActionRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .action

    @State
    private var status = "idle"

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .action,
                title: "Run"
            )
            .subtitle {
                Text(status)
            }
            .onActivate($status) {
                $0 = "ran"
            }
        }
        .frame(width: 32, height: 3, alignment: .leading)
    }
}

private struct RetortListBindingResetRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .reset

    @State
    private var status = "ran"

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .reset,
                title: "Reset"
            )
            .subtitle {
                Text(status)
            }
            .onReset($status) {
                $0 = "idle"
            }
        }
        .frame(width: 32, height: 3, alignment: .leading)
    }
}

private struct RetortListScrollRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    var body: some View {
        RetortList(selection: $selection) {
            for index in 0..<12 {
                RetortListItem(id: .item(index), title: "Item \(index)")
            }
        }
        .frame(width: 24, height: 4, alignment: .leading)
    }
}
