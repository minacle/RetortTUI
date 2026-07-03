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

    case navigation

    case item(Int)
}

private enum RuntimeChoice: String, CaseIterable {

    case development

    case production
}

private final class RetortListEditingProbe {

    var events: [RetortListEditingState<RuntimeListID>?] = []

    func record(_ state: RetortListEditingState<RuntimeListID>?) {
        events.append(state)
    }
}

private final class RetortListEditingController {

    var editing: RuntimeListID?

    init(editing: RuntimeListID? = nil) {
        self.editing = editing
    }
}

@Test func retortListPublicRowAPIsRenderThroughList() {
    let runtime = StateRuntime()
    let view = RetortListPublicAPIRuntimeView()
    let proposal = RenderProposal(columns: 48, rows: 4)
    let block = runtime.block(from: view, in: proposal)

    #expect(block?.lines.first?.hasPrefix("❯ ● Runtime title  subtitle") == true)
    #expect(block?.lines.contains { $0.contains("String title  value") } == true)
    #expect(block?.runs.contains {
        $0.text == "●" && $0.style == TextStyle(color: AnyColor(Color16.green), isBold: false)
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
        "❯ Child",
        "Action",
        "Resettable",
    ])
}

@Test func retortListTextRoleRendersWithoutSelectionFocusOrClicks() {
    let runtime = StateRuntime()
    let view = RetortListTextRoleRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 5)

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.hasPrefix("  Static") } == true)
    #expect(block?.lines.contains { $0.hasPrefix("❯ First") } == true)

    dispatchClick(to: runtime, column: 3, row: 2, expecting: .ignored)
    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.hasPrefix("❯ First") } == true)
    #expect(block?.lines.contains { $0.contains("idle") } == true)

    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())
    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.hasPrefix("❯ Action") } == true)
    #expect(block?.lines.contains { $0.hasPrefix("❯ Static") } == false)
}

@Test func retortListButtonRoleActivatesWithSpaceAndTap() {
    let spaceRuntime = StateRuntime()
    let spaceView = RetortListBindingActionRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 3)

    _ = spaceRuntime.block(from: spaceView, in: proposal)
    #expect(spaceRuntime.dispatch(KeyPress(key: .space, characters: " ")) == .handled)
    #expect(spaceRuntime.consumeInvalidation())
    #expect(spaceRuntime.block(from: spaceView, in: proposal)?.lines.first?.contains("ran") == true)

    let tapRuntime = StateRuntime()
    let tapView = RetortListBindingActionRuntimeView()

    _ = tapRuntime.block(from: tapView, in: proposal)
    dispatchClick(to: tapRuntime, column: 3, row: 1)
    #expect(tapRuntime.consumeInvalidation())
    #expect(tapRuntime.block(from: tapView, in: proposal)?.lines.first?.contains("ran") == true)
}

@Test func retortListNavigationLinkRoleActivatesDestination() {
    let runtime = StateRuntime()
    let view = RetortListNavigationLinkRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 3)

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.hasPrefix("❯ Open") } == true)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    block = runtime.block(from: view, in: proposal)
    #expect(block?.text == "Detail")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    dispatchClick(to: runtime, column: 3, row: 1)
    #expect(runtime.consumeInvalidation())
    block = runtime.block(from: view, in: proposal)
    #expect(block?.text == "Detail")
}

@Test func retortListRuntimeCollapsesAndExpandsTreeRows() {
    let runtime = StateRuntime()
    let view = RetortListTreeRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▾ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == true)
    #expect(block?.lines.contains { $0.hasPrefix("    Item 0") } == true)

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

@Test func retortListBoundCollapsedBindingControlsTreeRows() {
    let runtime = StateRuntime()
    let view = RetortListBoundCollapsedRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)

    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▸ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == false)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▾ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == true)

    #expect(runtime.dispatch(KeyPress(key: .space, characters: " ")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.contains { $0.contains("▸ Group") } == true)
    #expect(block?.lines.contains { $0.contains("Child") } == false)
}

@Test func retortListOmitsDisclosureSpaceWhenSiblingLevelHasNoGroups() {
    let runtime = StateRuntime()
    let view = RetortListNestedLeafRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)

    let block = runtime.block(from: view, in: proposal)

    #expect(block?.lines.first?.hasPrefix("❯ ▾ Group") == true)
    #expect(block?.lines.contains { $0.hasPrefix("      ● Accessory child") } == true)
    #expect(block?.lines.contains { $0.hasPrefix("      Plain child") } == true)
    #expect(block?.lines.contains { $0.hasPrefix("    ● Accessory child") } == false)
}

@Test func retortListReservesDisclosureSpaceWhenNestedSiblingLevelHasGroups() {
    let runtime = StateRuntime()
    let view = RetortListNestedGroupRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 6)

    let block = runtime.block(from: view, in: proposal)

    #expect(block?.lines.first?.hasPrefix("❯ ▾ Group") == true)
    #expect(block?.lines.contains { $0.hasPrefix("    ▾ Disclosure child") } == true)
    #expect(block?.lines.contains { $0.hasPrefix("    ▾ ● Both child") } == true)
}

@Test func retortListMastodonConfigurationShapeAlignsNestedMarkers() {
    let runtime = StateRuntime()
    let view = RetortListMastodonConfigurationRuntimeView()
    let proposal = RenderProposal(columns: 80, rows: 24)

    let lines = runtime.block(from: view, in: proposal)?.lines ?? []

    #expect(lines.contains { $0.hasPrefix("    ● Mode  official") })
    #expect(lines.contains { $0.hasPrefix("  ▾ ● Network Access  standard") })
    #expect(lines.contains { $0.hasPrefix("      ○ Trusted proxy IPs") })
    #expect(lines.contains { $0.hasPrefix("      ○ Private address exceptions") })
    #expect(lines.contains { $0.hasPrefix("      ● Limited federation mode  false") })
    #expect(lines.contains { $0.hasPrefix("  ▾ ● Admin  needs setup") })
    #expect(lines.contains { $0.hasPrefix("❯     ● Username") })
    #expect(lines.contains { $0.hasPrefix("      ● Role  Owner") })
    #expect(lines.contains { $0.hasPrefix("  ▸ ● Web  127.0.0.1:3000") })
    #expect(lines.contains { $0.hasPrefix("  ○ Trusted proxy IPs") } == false)
    #expect(lines.contains { $0.hasPrefix("● Username") } == false)
}

@Test func retortListTextEditorIndentationMatchesNestedRows() {
    #expect(
        openedTextEditorCursor(in: RetortListNestedPlainTextEditorRuntimeView())
            == RenderedCursor(row: 2, column: 10)
    )
    #expect(
        openedTextEditorCursor(in: RetortListNestedAccessoryTextEditorRuntimeView())
            == RenderedCursor(row: 2, column: 12)
    )
    #expect(
        openedTextEditorCursor(in: RetortListNestedReservedTextEditorRuntimeView())
            == RenderedCursor(row: 2, column: 10)
    )
    #expect(
        openedTextEditorCursor(in: RetortListNestedReservedAccessoryTextEditorRuntimeView())
            == RenderedCursor(row: 2, column: 12)
    )
    #expect(
        openedTextEditorCursor(in: RetortListMastodonConfigurationRuntimeView())
            == RenderedCursor(row: 11, column: 12)
    )
}

@Test func retortListKeyboardNavigationMovesRenderedSelection() {
    let runtime = StateRuntime()
    let view = RetortListNavigationRuntimeView()
    let proposal = RenderProposal(columns: 32, rows: 4)

    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯ Item 1") } == true)

    #expect(runtime.dispatch(KeyPress(key: .end, characters: "\u{F72B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯ Item 7") } == true)

    #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯ Item 6") } == true)

    #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines.contains { $0.hasPrefix("❯ Item 0") } == true)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageDownBlock = runtime.block(from: view, in: proposal)
    #expect(pageDownBlock?.lines.first?.hasPrefix("  Item 1") == true)
    #expect(pageDownBlock?.lines.last?.hasPrefix("❯ Item 4") == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageUpBlock = runtime.block(from: view, in: proposal)
    #expect(pageUpBlock?.lines.first?.hasPrefix("❯ Item 0") == true)
    #expect(pageUpBlock?.lines.last?.hasPrefix("  Item 3") == true)
}

@Test func retortListPageNavigationMovesByViewportAndClampsAtEnds() {
    let runtime = StateRuntime()
    let view = RetortListScrollRuntimeView()
    let proposal = RenderProposal(columns: 24, rows: 4)

    _ = runtime.block(from: view, in: proposal)

    for expectedLastLine in ["❯ Item 4", "❯ Item 8", "❯ Item 11", "❯ Item 11"] {
        #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view, in: proposal)
        #expect(block?.lines.last?.hasPrefix(expectedLastLine) == true)
    }

    for expectedFirstLine in ["❯ Item 7", "❯ Item 3", "❯ Item 0", "❯ Item 0"] {
        #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view, in: proposal)
        #expect(block?.lines.first?.hasPrefix(expectedFirstLine) == true)
    }
}

@Test func retortListPageNavigationJumpsAcrossThreeRows() {
    let runtime = StateRuntime()
    let view = RetortListThreeRowRuntimeView()
    let proposal = RenderProposal(columns: 24, rows: 2)

    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageDownBlock = runtime.block(from: view, in: proposal)
    #expect(pageDownBlock?.lines.last?.hasPrefix("❯ Item 2") == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageUpBlock = runtime.block(from: view, in: proposal)
    #expect(pageUpBlock?.lines.first?.hasPrefix("❯ Item 0") == true)
}

@Test func retortListPageNavigationUsesNaturalHeightWhenUnframed() {
    let runtime = StateRuntime()
    let view = RetortListUnframedThreeRowRuntimeView()
    let proposal = RenderProposal(columns: 24)

    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageDownBlock = runtime.block(from: view, in: proposal)
    #expect(pageDownBlock?.lines.last?.hasPrefix("❯ Item 2") == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageUpBlock = runtime.block(from: view, in: proposal)
    #expect(pageUpBlock?.lines.first?.hasPrefix("❯ Item 0") == true)
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
    #expect(editorBlock?.runs.contains {
        $0.text == "Editor" && $0.style.isBold
    } == true)

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
    #expect(movedBlock?.lines.contains { $0.hasPrefix("❯ Item 0") } == true)
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
    #expect(movedBlock?.lines.contains { $0.hasPrefix("❯ Item 0") } == true)
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

@Test func retortListTextEditingChangesReportDraftsAndClose() {
    let runtime = StateRuntime()
    let probe = RetortListEditingProbe()
    let view = RetortListObservedTextEditorRuntimeView(probe: probe)
    let proposal = RenderProposal(columns: 32, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events.isEmpty)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(probe.events == [.text(id: .editor, draft: "")])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [.text(id: .editor, draft: "")])

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        .text(id: .editor, draft: "a"),
    ])

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        .text(id: .editor, draft: "a"),
        nil,
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        .text(id: .editor, draft: "a"),
        nil,
    ])
}

@Test func retortListRejectedTextCommitKeepsEditingStateOpen() {
    let runtime = StateRuntime()
    let probe = RetortListEditingProbe()
    let view = RetortListObservedTextEditorRuntimeView(probe: probe)
    let proposal = RenderProposal(columns: 32, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(probe.events == [.text(id: .editor, draft: "")])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(probe.events == [.text(id: .editor, draft: "")])
    #expect(runtime.consumeInvalidation())
    let rejectedBlock = runtime.block(from: view, in: proposal)

    #expect(rejectedBlock?.lines.contains { $0.contains("Error: required") } == true)
    #expect(probe.events == [.text(id: .editor, draft: "")])
}

@Test func retortListChoiceEditingChangesReportSelectionAndClose() {
    let runtime = StateRuntime()
    let probe = RetortListEditingProbe()
    let view = RetortListObservedChoiceEditorRuntimeView(probe: probe)
    let proposal = RenderProposal(columns: 40, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])

    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        .choice(id: .choice, selectedIndex: 1, selectedChoice: "production"),
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        .choice(id: .choice, selectedIndex: 1, selectedChoice: "production"),
    ])

    dispatchClick(to: runtime, column: 4, row: 2)
    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        .choice(id: .choice, selectedIndex: 1, selectedChoice: "production"),
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        .choice(id: .choice, selectedIndex: 1, selectedChoice: "production"),
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        .choice(id: .choice, selectedIndex: 1, selectedChoice: "production"),
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        nil,
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        .choice(id: .choice, selectedIndex: 1, selectedChoice: "production"),
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        nil,
    ])

    let escapeRuntime = StateRuntime()
    let escapeProbe = RetortListEditingProbe()
    let escapeView = RetortListObservedChoiceEditorRuntimeView(probe: escapeProbe)

    _ = escapeRuntime.block(from: escapeView, in: proposal)
    _ = escapeRuntime.consumeInvalidation()
    _ = escapeRuntime.block(from: escapeView, in: proposal)

    #expect(escapeRuntime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(escapeProbe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])
    #expect(escapeRuntime.consumeInvalidation())
    _ = escapeRuntime.block(from: escapeView, in: proposal)

    #expect(escapeRuntime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(escapeProbe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        nil,
    ])
    #expect(escapeRuntime.consumeInvalidation())
    _ = escapeRuntime.block(from: escapeView, in: proposal)

    #expect(escapeProbe.events == [
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
        nil,
    ])
}

@Test func retortListEditingChangeCanDirectlyMutateParentStateFirstReadAfterAction() {
    let runtime = StateRuntime()
    let view = RetortListDirectEditingHintRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 6)

    let initialBlock = runtime.block(from: view, in: proposal)
    #expect(initialBlock?.lines.contains { $0.contains("idle") } == true)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editingBlock = runtime.block(from: view, in: proposal)

    #expect(editingBlock?.lines.contains { $0.contains("development") } == true)
}

@Test func retortListChoiceEditingChangeUpdatesConditionalFooterHint() {
    let runtime = StateRuntime()
    let view = RetortListConditionalFooterHintRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 6)

    let initialBlock = runtime.block(from: view, in: proposal)
    #expect(initialBlock?.lines.contains { $0.contains("idle") } == true)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editingBlock = runtime.block(from: view, in: proposal)

    #expect(editingBlock?.lines.contains { $0.contains("production") } == true)
}

@Test func retortListControlledEditingBindingTracksUserOpenAndClose() {
    let runtime = StateRuntime()
    let controller = RetortListEditingController()
    let probe = RetortListEditingProbe()
    let view = RetortListControlledEditingRuntimeView(
        controller: controller,
        probe: probe,
        initialSelection: .editor
    )
    let proposal = RenderProposal(columns: 40, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(controller.editing == nil)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(controller.editing == .editor)
    #expect(probe.events == [.text(id: .editor, draft: "")])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [.text(id: .editor, draft: "")])

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(controller.editing == nil)
    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        nil,
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        nil,
    ])
}

@Test func retortListControlledEditingBindingOpensClosesAndNormalizesRequests() {
    let runtime = StateRuntime()
    let controller = RetortListEditingController(editing: .editor)
    let probe = RetortListEditingProbe()
    let view = RetortListControlledEditingRuntimeView(
        controller: controller,
        probe: probe,
        initialSelection: .item(0)
    )
    let proposal = RenderProposal(columns: 40, rows: 5)

    _ = runtime.block(from: view, in: proposal)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(controller.editing == .editor)
    #expect(probe.events == [.text(id: .editor, draft: "")])

    controller.editing = nil
    _ = runtime.block(from: view, in: proposal)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        nil,
    ])

    controller.editing = .choice
    _ = runtime.block(from: view, in: proposal)
    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        nil,
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(probe.events == [
        .text(id: .editor, draft: ""),
        nil,
        .choice(id: .choice, selectedIndex: 0, selectedChoice: "development"),
    ])

    controller.editing = .item(0)
    _ = runtime.block(from: view, in: proposal)

    #expect(controller.editing == nil)
}

@Test func retortListChoiceEditorPageNavigationUsesViewportRows() {
    let runtime = StateRuntime()
    let view = RetortListLongChoiceEditorRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 4)

    _ = runtime.block(from: view, in: proposal)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageDownBlock = runtime.block(from: view, in: proposal)
    #expect(pageDownBlock?.lines.first?.contains("Option 1") == true)
    #expect(pageDownBlock?.lines.last?.contains("❯ Option 4") == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageUpBlock = runtime.block(from: view, in: proposal)
    #expect(pageUpBlock?.lines.first?.contains("❯ Option 0") == true)
    #expect(pageUpBlock?.lines.last?.contains("Option 3") == true)
}

@Test func retortListChoiceEditorPageNavigationJumpsAcrossThreeItems() {
    let runtime = StateRuntime()
    let view = RetortListThreeChoiceEditorRuntimeView()
    let proposal = RenderProposal(columns: 40, rows: 2)

    _ = runtime.block(from: view, in: proposal)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageDownBlock = runtime.block(from: view, in: proposal)
    #expect(pageDownBlock?.lines.last?.contains("❯ Option 2") == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageUpBlock = runtime.block(from: view, in: proposal)
    #expect(pageUpBlock?.lines.first?.contains("❯ Option 0") == true)
}

@Test func retortListChoiceEditorPageNavigationUsesNaturalHeightWhenUnframed() {
    let runtime = StateRuntime()
    let view = RetortListUnframedThreeChoiceEditorRuntimeView()
    let proposal = RenderProposal(columns: 40)

    _ = runtime.block(from: view, in: proposal)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .pageDown, characters: "\u{F72D}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageDownBlock = runtime.block(from: view, in: proposal)
    #expect(pageDownBlock?.lines.last?.contains("❯ Option 2") == true)

    #expect(runtime.dispatch(KeyPress(key: .pageUp, characters: "\u{F72C}")) == .handled)
    #expect(runtime.consumeInvalidation())
    let pageUpBlock = runtime.block(from: view, in: proposal)
    #expect(pageUpBlock?.lines.contains { $0.contains("❯ Option 0") } == true)
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

private func openedTextEditorCursor<Content: View>(
    in view: Content
) -> RenderedCursor? {
    let runtime = StateRuntime()
    let proposal = RenderProposal(columns: 40, rows: 6)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    _ = runtime.consumeInvalidation()

    return runtime.block(from: view, in: proposal)?.cursor
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
            RetortListItem(id: .item(0), role: .button) {
                Text("Runtime title")
            }
            .subtitle {
                Text("subtitle")
            }
            .leadingAccessory {
                Text("●").color(.green)
            }
            .onActivate {}

            RetortListItem(id: .editor, role: .button, title: "String title")
                .editor($value)

            RetortListItem(id: .reset, role: .button, title: "Reset row")
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
                RetortListItem(id: .child, role: .button, title: "Child")
            }

            for id in ids {
                RetortListItem(
                    id: id,
                    role: .button,
                    title: id == .action ? "Action" : "Resettable"
                )
            }
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListTextRoleRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    @State
    private var status = "idle"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RetortList(selection: $selection) {
                RetortListItem(id: .item(0), role: .button, title: "First")
                RetortListItem(id: .item(1), role: .text, title: "Static")
                RetortListItem(id: .action, role: .button, title: "Action")
                    .onActivate($status) {
                        $0 = "ran"
                    }
            }
            Text(status)
        }
        .frame(width: 32, height: 5, alignment: .leading)
    }
}

private struct RetortListNavigationLinkRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .navigation

    var body: some View {
        NavigationStack {
            RetortList(selection: $selection) {
                RetortListItem(id: .navigation, role: .navigationLink) {
                    Text("Detail")
                } title: {
                    Text("Open")
                }
            }
            .frame(width: 32, height: 3, alignment: .leading)
        }
    }
}

private struct RetortListTreeRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .group

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .child, role: .button, title: "Child")
            }
            RetortListItem(id: .item(0), role: .button, title: "Item 0")
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListBoundCollapsedRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .group

    @State
    private var collapsed = true

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .group,
                role: .button,
                title: "Group",
                collapsed: $collapsed
            ) {
                RetortListItem(id: .child, role: .button, title: "Child")
            }
            RetortListItem(id: .item(0), role: .button, title: "Item 0")
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListNestedLeafRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .group

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .child, role: .button, title: "Accessory child")
                    .leadingAccessory {
                        Text("●").color(.green)
                    }
                RetortListItem(id: .item(0), role: .button, title: "Plain child")
            }
        }
        .frame(width: 40, height: 5, alignment: .leading)
    }
}

private struct RetortListNestedGroupRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .group

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .item(10), role: .button, title: "Disclosure child") {
                    RetortListItem(id: .item(11), role: .button, title: "Grandchild")
                }
                RetortListItem(id: .item(12), role: .button, title: "Both child") {
                    RetortListItem(id: .item(13), role: .button, title: "Both grandchild")
                }
                .leadingAccessory {
                    Text("●").color(.green)
                }
            }
        }
        .frame(width: 40, height: 6, alignment: .leading)
    }
}

private struct RetortListMastodonConfigurationRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(10)

    @State
    private var username = ""

    @State
    private var webCollapsed = true

    var body: some View {
        RetortList(selection: $selection) {
            configurationItem(id: .item(0), title: "Mode", marker: "●", subtitle: "official")
            configurationItem(id: .item(1), title: "Version", marker: "●", subtitle: "v4.6")
            configurationItem(id: .item(2), title: "Local domain", marker: "●")
            configurationItem(id: .item(3), title: "Server name", marker: "●")

            configurationGroup(
                id: .item(4),
                title: "Network Access",
                marker: "●",
                subtitle: "standard"
            ) {
                configurationItem(id: .item(5), title: "Trusted proxy IPs", marker: "○")
                configurationItem(id: .item(6), title: "Private address exceptions", marker: "○")
                configurationItem(id: .item(7), title: "Limited federation mode", marker: "●", subtitle: "false")
                configurationItem(id: .item(8), title: "Authenticated API access", marker: "●", subtitle: "false")
            }

            configurationGroup(
                id: .item(9),
                title: "Admin",
                marker: "●",
                subtitle: "needs setup"
            ) {
                configurationItem(id: .item(10), title: "Username", marker: "●")
                    .editor($username)
                configurationItem(id: .item(11), title: "Email", marker: "●")
                configurationItem(id: .item(12), title: "Password", marker: "●")
                configurationItem(id: .item(13), title: "Role", marker: "●", subtitle: "Owner")
            }

            configurationGroup(
                id: .item(14),
                title: "Web",
                marker: "●",
                subtitle: "127.0.0.1:3000",
                collapsed: $webCollapsed
            ) {
                configurationItem(id: .item(15), title: "IP address", marker: "●", subtitle: "127.0.0.1")
                configurationItem(id: .item(16), title: "Port", marker: "●", subtitle: "3000")
            }
        }
        .frame(width: 80, height: 24, alignment: .leading)
    }

    private func configurationItem(
        id: RuntimeListID,
        title: String,
        marker: String,
        subtitle: String? = nil
    ) -> RetortListItem<RuntimeListID> {
        var item = RetortListItem(id: id, role: .button, title: title)
            .leadingAccessory {
                Text(marker)
            }

        if let subtitle {
            item = item.subtitle {
                Text(subtitle)
            }
        }

        return item
    }

    private func configurationGroup(
        id: RuntimeListID,
        title: String,
        marker: String,
        subtitle: String? = nil,
        collapsed: Binding<Bool>? = nil,
        @RetortListItemBuilder<RuntimeListID> children: () -> [RetortListItem<RuntimeListID>]
    ) -> RetortListItem<RuntimeListID> {
        var item = RetortListItem(
            id: id,
            role: .button,
            title: title,
            collapsed: collapsed,
            children: children
        )
        .leadingAccessory {
            Text(marker)
        }

        if let subtitle {
            item = item.subtitle {
                Text(subtitle)
            }
        }

        return item
    }
}

private struct RetortListNestedPlainTextEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(20)

    @State
    private var value = ""

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .item(20), role: .button, title: "Plain editor")
                    .editor($value)
            }
        }
        .frame(width: 40, height: 6, alignment: .leading)
    }
}

private struct RetortListNestedAccessoryTextEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(21)

    @State
    private var value = ""

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .item(21), role: .button, title: "Accessory editor")
                    .leadingAccessory {
                        Text("●").color(.green)
                    }
                    .editor($value)
            }
        }
        .frame(width: 40, height: 6, alignment: .leading)
    }
}

private struct RetortListNestedReservedTextEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(22)

    @State
    private var value = ""

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .item(22), role: .button, title: "Reserved editor")
                    .editor($value)
                RetortListItem(id: .item(23), role: .button, title: "Disclosure sibling") {
                    RetortListItem(id: .item(24), role: .button, title: "Grandchild")
                }
            }
        }
        .frame(width: 40, height: 6, alignment: .leading)
    }
}

private struct RetortListNestedReservedAccessoryTextEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(25)

    @State
    private var value = ""

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(id: .group, role: .button, title: "Group") {
                RetortListItem(id: .item(25), role: .button, title: "Reserved accessory editor")
                    .leadingAccessory {
                        Text("●").color(.green)
                    }
                    .editor($value)
                RetortListItem(id: .item(26), role: .button, title: "Disclosure sibling") {
                    RetortListItem(id: .item(27), role: .button, title: "Grandchild")
                }
            }
        }
        .frame(width: 40, height: 6, alignment: .leading)
    }
}

private struct RetortListNavigationRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    var body: some View {
        RetortList(selection: $selection) {
            for index in 0..<8 {
                RetortListItem(id: .item(index), role: .button, title: "Item \(index)")
            }
        }
        .frame(width: 32, height: 4, alignment: .leading)
    }
}

private struct RetortListThreeRowRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    var body: some View {
        RetortList(selection: $selection) {
            for index in 0..<3 {
                RetortListItem(id: .item(index), role: .button, title: "Item \(index)")
            }
        }
        .frame(width: 24, height: 2, alignment: .leading)
    }
}

private struct RetortListUnframedThreeRowRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    var body: some View {
        RetortList(selection: $selection) {
            for index in 0..<3 {
                RetortListItem(id: .item(index), role: .button, title: "Item \(index)")
            }
        }
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
                role: .button,
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
                RetortListItem(id: .item(index), role: .button, title: "Item \(index)")
            }
        }
        .frame(width: 32, height: 5, alignment: .leading)
    }
}

private struct RetortListObservedTextEditorRuntimeView: View {

    let probe: RetortListEditingProbe

    @FocusState
    private var selection: RuntimeListID? = .editor

    @State
    private var value = ""

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .editor,
                role: .button,
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
        }
        .onEditingChange {
            probe.record($0)
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
                role: .button,
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
                RetortListItem(id: .item(index), role: .button, title: "Item \(index)")
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
                role: .button,
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
                role: .button,
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
                role: .button,
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

private struct RetortListObservedChoiceEditorRuntimeView: View {

    let probe: RetortListEditingProbe

    @FocusState
    private var selection: RuntimeListID? = .choice

    @State
    private var value = RuntimeChoice.development

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .choice,
                role: .button,
                title: "Choice"
            )
            .choices(
                $value,
                from: RuntimeChoice.allCases,
                name: \.rawValue
            )
        }
        .onEditingChange {
            probe.record($0)
        }
        .frame(width: 40, height: 5, alignment: .leading)
    }
}

private struct RetortListDirectEditingHintRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .choice

    @State
    private var editing: RuntimeListID?

    @State
    private var value = RuntimeChoice.development

    @State
    private var hint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RetortList(selection: $selection, editing: $editing) {
                RetortListItem(
                    id: .choice,
                    role: .button,
                    title: "Choice"
                )
                .choices(
                    $value,
                    from: RuntimeChoice.allCases,
                    name: \.rawValue
                )
            }
            .onEditingChange {
                guard case .choice(_, _, let title) = $0 else {
                    hint = ""
                    return
                }

                hint = title.lowercased()
            }
            .frame(width: 40, height: 4, alignment: .leading)

            if editing == nil {
                Text("idle")
            }
            else {
                Text(hint.isEmpty ? "empty" : hint)
            }
        }
    }
}

private struct RetortListConditionalFooterHintRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .item(0)

    @State
    private var editing: RuntimeListID?

    @State
    private var editingItemHint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RetortList(selection: $selection, editing: $editing) {
                RetortListItem(
                    id: .item(0),
                    role: .button,
                    title: "example.social"
                )
                .choices(
                    .constant(RuntimeChoice.production),
                    from: [RuntimeChoice.production],
                    name: \.rawValue
                )
                .subtitle {
                    Text("")
                }
            }
            .onEditingChange {
                guard case .choice(_, _, let title) = $0 else {
                    editingItemHint = ""
                    return
                }

                editingItemHint = title.lowercased()
            }
            .frame(width: 40, height: 4, alignment: .leading)

            if editing == nil {
                Text("idle")
            }
            else {
                HStack(spacing: 1) {
                    Text("return")
                    Text(editingItemHint)
                }
            }
        }
    }
}

private struct RetortListControlledEditingRuntimeView: View {

    let controller: RetortListEditingController

    let probe: RetortListEditingProbe

    let initialSelection: RuntimeListID?

    @FocusState
    private var selection: RuntimeListID?

    @State
    private var text = ""

    @State
    private var choice = RuntimeChoice.development

    init(
        controller: RetortListEditingController,
        probe: RetortListEditingProbe,
        initialSelection: RuntimeListID?
    ) {
        self.controller = controller
        self.probe = probe
        self.initialSelection = initialSelection
        self._selection = FocusState(wrappedValue: initialSelection)
    }

    var body: some View {
        RetortList(
            selection: $selection,
            editing: Binding(
                get: {
                    controller.editing
                },
                set: {
                    controller.editing = $0
                }
            )
        ) {
            RetortListItem(
                id: .editor,
                role: .button,
                title: "Editor"
            )
            .editor(
                $text,
                validate: {
                    guard !$0.isEmpty else {
                        return .rejected("required")
                    }

                    return .accepted
                }
            )

            RetortListItem(
                id: .choice,
                role: .button,
                title: "Choice"
            )
            .choices(
                $choice,
                from: RuntimeChoice.allCases,
                name: \.rawValue
            )

            RetortListItem(id: .item(0), role: .button, title: "Plain")
        }
        .onEditingChange {
            probe.record($0)
        }
        .frame(width: 40, height: 5, alignment: .leading)
    }
}

private struct RetortListLongChoiceEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .choice

    @State
    private var value = 0

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .choice,
                role: .button,
                title: "Choice"
            )
            .choices(
                $value,
                from: Array(0..<8),
                name: { "Option \($0)" }
            )
        }
        .frame(width: 40, height: 4, alignment: .leading)
    }
}

private func dispatchClick(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    at date: Date = Date(timeIntervalSinceReferenceDate: 1_000),
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .down),
            at: date
        ) == result
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .up),
            at: date
        ) == result
    )
}

private struct RetortListThreeChoiceEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .choice

    @State
    private var value = 0

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .choice,
                role: .button,
                title: "Choice"
            )
            .choices(
                $value,
                from: Array(0..<3),
                name: { "Option \($0)" }
            )
        }
        .frame(width: 40, height: 2, alignment: .leading)
    }
}

private struct RetortListUnframedThreeChoiceEditorRuntimeView: View {

    @FocusState
    private var selection: RuntimeListID? = .choice

    @State
    private var value = 0

    var body: some View {
        RetortList(selection: $selection) {
            RetortListItem(
                id: .choice,
                role: .button,
                title: "Choice"
            )
            .choices(
                $value,
                from: Array(0..<3),
                name: { "Option \($0)" }
            )
        }
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
                role: .button,
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
                role: .button,
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
                RetortListItem(id: .item(index), role: .button, title: "Item \(index)")
            }
        }
        .frame(width: 24, height: 4, alignment: .leading)
    }
}
