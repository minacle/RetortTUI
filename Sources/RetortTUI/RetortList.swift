import SwiftTUI

/// The result of committing an inline list editor.
public enum RetortListCommitResult: Equatable, Sendable {

    case accepted

    case rejected(String)
}

/// An inline editor that can be opened from a ``RetortListItem``.
enum RetortListEditor {

    case text(
        initialValue: String,
        commit: (String) -> RetortListCommitResult
    )

    case choice(
        choices: [String],
        selectedIndex: Int,
        commit: (Int) -> RetortListCommitResult
    )
}

struct RetortListItemConfiguration<ID> where ID: Hashable {

    var id: ID

    var title: AnyView

    var subtitle: AnyView?

    var leadingAccessory: AnyView?

    var editor: RetortListEditor?

    var action: (() -> Void)?

    var reset: (() -> Void)?

    var children: [RetortListItem<ID>]
}

/// A row view interpreted by ``RetortList``.
public struct RetortListItem<ID>: View where ID: Hashable {

    public typealias Body = Never

    var configuration: RetortListItemConfiguration<ID>

    public init<Title: View>(
        id: ID,
        @ViewBuilder title: () -> Title
    ) {
        self.configuration = RetortListItemConfiguration(
            id: id,
            title: AnyView(title()),
            subtitle: nil,
            leadingAccessory: nil,
            editor: nil,
            action: nil,
            reset: nil,
            children: []
        )
    }

    public init(
        id: ID,
        title: String,
        @RetortListItemBuilder<ID> children: () -> [Self] = { [] }
    ) {
        self.init(
            id: id,
            title: Text(title),
            children: children
        )
    }

    public init(
        id: ID,
        title: Text,
        @RetortListItemBuilder<ID> children: () -> [Self] = { [] }
    ) {
        self.configuration = RetortListItemConfiguration(
            id: id,
            title: AnyView(title),
            subtitle: nil,
            leadingAccessory: nil,
            editor: nil,
            action: nil,
            reset: nil,
            children: children()
        )
    }

    public func subtitle<Subtitle: View>(
        @ViewBuilder _ subtitle: () -> Subtitle
    ) -> Self {
        var copy = self
        copy.configuration.subtitle = AnyView(subtitle())
        return copy
    }

    public func leadingAccessory<Accessory: View>(
        @ViewBuilder _ accessory: () -> Accessory
    ) -> Self {
        var copy = self
        copy.configuration.leadingAccessory = AnyView(accessory())
        return copy
    }

    public func editor<Value>(
        _ value: Binding<Value>,
        text: @escaping (Value) -> String,
        parse: @escaping (String) -> Value?,
        invalidMessage: String = "enter a valid value",
        validate: @escaping (Value) -> RetortListCommitResult = { _ in .accepted }
    ) -> Self {
        var copy = self
        copy.configuration.subtitle = AnyView(Text(text(value.wrappedValue)))
        copy.configuration.editor = .text(initialValue: text(value.wrappedValue)) {
            newValue in

            guard let parsedValue = parse(newValue) else {
                return .rejected(invalidMessage)
            }

            let result = validate(parsedValue)
            if case .accepted = result {
                value.wrappedValue = parsedValue
            }
            return result
        }
        return copy
    }

    public func editor<Value>(
        _ value: Binding<Value>,
        invalidMessage: String = "enter a valid value",
        validate: @escaping (Value) -> RetortListCommitResult = { _ in .accepted }
    ) -> Self where Value: LosslessStringConvertible {
        editor(
            value,
            text: { String($0) },
            parse: Value.init,
            invalidMessage: invalidMessage,
            validate: validate
        )
    }

    public func choices<Value>(
        _ value: Binding<Value>,
        from choices: [Value],
        name: @escaping (Value) -> String,
        validate: @escaping (Value) -> RetortListCommitResult = { _ in .accepted }
    ) -> Self where Value: Equatable {
        let selectedIndex = choices.firstIndex(of: value.wrappedValue) ?? 0

        var copy = self
        copy.configuration.subtitle = AnyView(Text(name(value.wrappedValue)))
        copy.configuration.editor = .choice(
            choices: choices.map(name),
            selectedIndex: selectedIndex
        ) {
            selectedIndex in

            guard choices.indices.contains(selectedIndex) else {
                return .rejected("choose a valid option")
            }

            let selectedValue = choices[selectedIndex]
            let result = validate(selectedValue)
            if case .accepted = result {
                value.wrappedValue = selectedValue
            }
            return result
        }
        return copy
    }

    public func onActivate(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.configuration.action = action
        return copy
    }

    public func onActivate<Value>(
        _ value: Binding<Value>,
        perform action: @escaping (inout Value) -> Void
    ) -> Self {
        onActivate {
            var newValue = value.wrappedValue
            action(&newValue)
            value.wrappedValue = newValue
        }
    }

    public func onReset(_ reset: @escaping () -> Void) -> Self {
        var copy = self
        copy.configuration.reset = reset
        return copy
    }

    public func onReset<Value>(
        _ value: Binding<Value>,
        perform reset: @escaping (inout Value) -> Void
    ) -> Self {
        onReset {
            var newValue = value.wrappedValue
            reset(&newValue)
            value.wrappedValue = newValue
        }
    }
}

/// Builds list item trees for ``RetortList``.
@resultBuilder
public enum RetortListItemBuilder<ID> where ID: Hashable {

    public static func buildExpression(
        _ expression: RetortListItem<ID>
    ) -> [RetortListItem<ID>] {
        [expression]
    }

    public static func buildExpression(
        _ expression: [RetortListItem<ID>]
    ) -> [RetortListItem<ID>] {
        expression
    }

    public static func buildBlock(
        _ components: [RetortListItem<ID>]...
    ) -> [RetortListItem<ID>] {
        components.flatMap { $0 }
    }

    public static func buildOptional(
        _ component: [RetortListItem<ID>]?
    ) -> [RetortListItem<ID>] {
        component ?? []
    }

    public static func buildEither(
        first component: [RetortListItem<ID>]
    ) -> [RetortListItem<ID>] {
        component
    }

    public static func buildEither(
        second component: [RetortListItem<ID>]
    ) -> [RetortListItem<ID>] {
        component
    }

    public static func buildArray(
        _ components: [[RetortListItem<ID>]]
    ) -> [RetortListItem<ID>] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(
        _ component: [RetortListItem<ID>]
    ) -> [RetortListItem<ID>] {
        component
    }
}

/// A selectable rows-only tree list built on top of SwiftTUI public primitives.
public struct RetortList<ID>: View where ID: Hashable {

    private let items: [RetortListItem<ID>]

    private let selection: FocusState<ID?>.Binding

    public init(
        selection: FocusState<ID?>.Binding,
        @RetortListItemBuilder<ID> content: () -> [RetortListItem<ID>]
    ) {
        self.selection = selection
        self.items = content()
    }

    public var body: some View {
        GeometryReader {
            proxy in

            RetortListStorage(
                items: items,
                selection: selection,
                viewportRows: max(proxy.rows, 1)
            )
        }
    }
}

private struct RetortListStorage<ID>: View where ID: Hashable {

    let items: [RetortListItem<ID>]

    let selection: FocusState<ID?>.Binding

    let viewportRows: Int

    @State
    private var collapsedIDs: Set<ID> = []

    @State
    private var activeEditor: RetortListActiveEditor<ID>?

    @State
    private var editorDraft = ""

    @State
    private var scrollPosition = ScrollPosition()

    @FocusState
    private var isTextEditorFocused: Bool

    var body: some View {
        ScrollView(.vertical) {
            listContent
        }
        .scrollPosition($scrollPosition)
        .onKeyPress(keys: [.upArrow, .downArrow, .home, .end, .pageUp, .pageDown]) {
            keyPress in

            handleNavigation(keyPress.key)
        }
        .onKeyPress(.return) {
            handleReturn()
        }
        .onKeyPress(.space) {
            handleSpace()
        }
        .onKeyPress(keys: [.delete, .deleteForward]) {
            _ in

            handleReset()
        }
        .onKeyPress(.escape) {
            handleEscape()
        }
    }

    private var visibleRows: [RetortListRow<ID>] {
        RetortListModel.rows(from: items, collapsedIDs: collapsedIDs)
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleRows, id: \.id) {
                row in

                Group {
                    rowView(row)

                    if isTextEditorActive(for: row) {
                        textEditorView(row)
                    }

                    if isChoiceEditorActive(for: row),
                       let activeEditor,
                       let choices = activeEditor.choices {
                        choiceEditorView(row, choices: choices)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: RetortListRow<ID>) -> some View {
        let isSelected = selection.wrappedValue == row.id && activeEditor?.id != row.id

        HStack(spacing: 0) {
            Text(rowCursor(isSelected: isSelected))
                .bold(isSelected)
            Text(row.prefix)
            if let leadingAccessory = row.item.configuration.leadingAccessory {
                leadingAccessory
                Text(" ")
            }
            row.item.configuration.title
                .bold(selection.wrappedValue == row.id)
            if let subtitle = row.item.configuration.subtitle {
                Text("  ")
                subtitle
                    .color(.brightBlack)
            }
            Spacer()
        }
        .focusable(!isTextEditorActive(for: row))
        .focused(selection, equals: row.id)
        .onTapGesture {
            selection.wrappedValue = row.id
        }
    }

    @ViewBuilder
    private func textEditorView(_ row: RetortListRow<ID>) -> some View {
        HStack(spacing: 0) {
            Text(editorCursorPrefix(for: row, isSelected: true))
                .bold()
            TextField(
                "",
                text: $editorDraft
            )
            .focused($isTextEditorFocused)
            .onSubmit {
                commitActiveEditor(for: row.item)
                scrollSelectionIntoView()
            }
            Spacer()
        }

        if let errorMessage = activeEditor?.errorMessage {
            HStack(spacing: 0) {
                Text(editorCursorPrefix(for: row, isSelected: false))
                Text("Error: \(errorMessage)")
                    .color(.red)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func choiceEditorView(
        _ row: RetortListRow<ID>,
        choices: [String]
    ) -> some View {
        ForEach(choices.indices, id: \.self) {
            index in

            let isSelected = index == activeEditor?.selectedChoiceIndex

            HStack(spacing: 0) {
                Text(editorCursorPrefix(for: row, isSelected: isSelected))
                    .bold(isSelected)
                Text(choices[index])
                    .bold(isSelected)
                Spacer()
            }
            .onTapGesture {
                activeEditor?.selectedChoiceIndex = index
            }
        }
    }

    private func handleNavigation(_ key: KeyEquivalent) -> KeyPress.Result {
        if activeEditor?.choices != nil {
            moveChoiceSelection(key)
            scrollSelectionIntoView()
            return .handled
        }

        guard activeEditor == nil else {
            return .ignored
        }

        let input = RetortListNavigationInput(key: key)
        guard let input else {
            return .ignored
        }

        selection.wrappedValue = RetortListModel.movedSelection(
            selection.wrappedValue,
            input: input,
            rows: visibleRows,
            pageSize: viewportRows
        )
        scrollSelectionIntoView()
        return .handled
    }

    private func handleReturn() -> KeyPress.Result {
        if activeEditor != nil {
            guard let row = selectedRow else {
                return .ignored
            }

            commitActiveEditor(for: row.item)
            scrollSelectionIntoView()
            return .handled
        }

        guard let row = selectedRow else {
            return .ignored
        }

        if row.isGroup {
            toggle(row.id)
            scrollSelectionIntoView()
            return .handled
        }

        if let editor = row.item.configuration.editor {
            openEditor(editor, for: row.id)
            scrollSelectionIntoView()
            return .handled
        }

        if let action = row.item.configuration.action {
            action()
            return .handled
        }

        return .ignored
    }

    private func handleSpace() -> KeyPress.Result {
        guard activeEditor == nil,
              let row = selectedRow,
              row.isGroup else {
            return .ignored
        }

        toggle(row.id)
        scrollSelectionIntoView()
        return .handled
    }

    private func handleReset() -> KeyPress.Result {
        guard activeEditor == nil,
              let row = selectedRow,
              let reset = row.item.configuration.reset else {
            return .ignored
        }

        reset()
        return .handled
    }

    private func handleEscape() -> KeyPress.Result {
        guard let activeEditor else {
            return .ignored
        }

        self.activeEditor = nil
        isTextEditorFocused = false
        refocusRow(activeEditor.id)
        return .handled
    }

    private var selectedRow: RetortListRow<ID>? {
        let selection = selection.wrappedValue
        return visibleRows.first {
            $0.id == selection
        }
    }

    private func toggle(_ id: ID) {
        if collapsedIDs.contains(id) {
            collapsedIDs.remove(id)
        }
        else {
            collapsedIDs.insert(id)
        }
    }

    private func openEditor(_ editor: RetortListEditor, for id: ID) {
        let nextEditor = RetortListActiveEditor(id: id, editor: editor)
        activeEditor = nextEditor
        editorDraft = nextEditor.draft
        switch editor {
        case .text:
            isTextEditorFocused = true
        case .choice:
            isTextEditorFocused = false
        }
    }

    private func commitActiveEditor(for item: RetortListItem<ID>) {
        guard let editor = item.configuration.editor,
              var activeEditor else {
            return
        }
        activeEditor.draft = editorDraft

        let result: RetortListCommitResult
        switch editor {
        case .text(_, let commit):
            result = commit(activeEditor.draft)
        case .choice(_, _, let commit):
            result = commit(activeEditor.selectedChoiceIndex)
        }

        switch result {
        case .accepted:
            self.activeEditor = nil
            isTextEditorFocused = false
            refocusRow(activeEditor.id)
        case .rejected(let message):
            activeEditor.errorMessage = message
            self.activeEditor = activeEditor
            isTextEditorFocused = activeEditor.choices == nil
        }
    }

    private func refocusRow(_ id: ID) {
        selection.wrappedValue = nil
        selection.wrappedValue = id
    }

    private func moveChoiceSelection(_ key: KeyEquivalent) {
        guard var activeEditor,
              let choices = activeEditor.choices,
              !choices.isEmpty else {
            return
        }

        let index = activeEditor.selectedChoiceIndex
        switch key {
        case .upArrow, .leftArrow:
            activeEditor.selectedChoiceIndex = max(index - 1, 0)
        case .downArrow, .rightArrow:
            activeEditor.selectedChoiceIndex = min(index + 1, choices.count - 1)
        case .home:
            activeEditor.selectedChoiceIndex = 0
        case .end:
            activeEditor.selectedChoiceIndex = choices.count - 1
        case .pageUp:
            activeEditor.selectedChoiceIndex = max(index - viewportRows, 0)
        case .pageDown:
            activeEditor.selectedChoiceIndex = min(index + viewportRows, choices.count - 1)
        default:
            break
        }

        self.activeEditor = activeEditor
    }

    private func isTextEditorActive(for row: RetortListRow<ID>) -> Bool {
        activeEditor?.id == row.id && activeEditor?.choices == nil
    }

    private func isChoiceEditorActive(for row: RetortListRow<ID>) -> Bool {
        activeEditor?.id == row.id && activeEditor?.choices != nil
    }

    private func rowCursor(isSelected: Bool) -> String {
        isSelected ? "❯ " : "  "
    }

    private func scrollSelectionIntoView() {
        let rows = visibleRows
        let nextY = RetortListModel.scrollY(
            currentY: scrollPosition.y ?? 0,
            targetRange: RetortListModel.targetLineRange(
                selection: selection.wrappedValue,
                activeEditor: activeEditor,
                rows: rows
            ),
            viewportRows: viewportRows,
            contentLineCount: RetortListModel.contentLines(
                from: rows,
                activeEditor: activeEditor
            )
            .count
        )

        scrollPosition.scrollTo(y: nextY)
    }

    private func editorCursorPrefix(
        for row: RetortListRow<ID>,
        isSelected: Bool
    ) -> String {
        RetortListModel.editorCursorPrefix(
            forDepth: row.depth,
            isSelected: isSelected
        )
    }
}

struct RetortListRow<ID>: Identifiable where ID: Hashable {

    var id: ID

    var depth: Int

    var item: RetortListItem<ID>

    var isCollapsed: Bool

    var isGroup: Bool {
        !item.configuration.children.isEmpty
    }

    var prefix: String {
        let indent = String(repeating: "  ", count: depth)
        guard isGroup else {
            return indent + "  "
        }

        return indent + (isCollapsed ? "▸ " : "▾ ")
    }
}

enum RetortListNavigationInput {

    case up

    case down

    case home

    case end

    case pageUp

    case pageDown

    init?(key: KeyEquivalent) {
        switch key {
        case .upArrow:
            self = .up
        case .downArrow:
            self = .down
        case .home:
            self = .home
        case .end:
            self = .end
        case .pageUp:
            self = .pageUp
        case .pageDown:
            self = .pageDown
        default:
            return nil
        }
    }
}

struct RetortListContentLine<ID>: Equatable where ID: Hashable {

    enum Kind: Equatable {

        case row

        case textEditor

        case textEditorError

        case choice(Int)
    }

    var id: ID

    var kind: Kind
}

enum RetortListModel {

    static func rows<ID>(
        from items: [RetortListItem<ID>],
        collapsedIDs: Set<ID>
    ) -> [RetortListRow<ID>] where ID: Hashable {
        items.flatMap {
            rows(for: $0, depth: 0, collapsedIDs: collapsedIDs)
        }
    }

    static func rows<ID>(
        for item: RetortListItem<ID>,
        depth: Int,
        collapsedIDs: Set<ID>
    ) -> [RetortListRow<ID>] where ID: Hashable {
        let isCollapsed = collapsedIDs.contains(item.configuration.id)
        let row = RetortListRow(
            id: item.configuration.id,
            depth: depth,
            item: item,
            isCollapsed: isCollapsed
        )

        guard !isCollapsed else {
            return [row]
        }

        return [row] + item.configuration.children.flatMap {
            rows(for: $0, depth: depth + 1, collapsedIDs: collapsedIDs)
        }
    }

    static func movedSelection<ID>(
        _ selection: ID?,
        input: RetortListNavigationInput,
        rows: [RetortListRow<ID>],
        pageSize: Int
    ) -> ID? where ID: Hashable {
        guard !rows.isEmpty else {
            return nil
        }

        let currentIndex = selection.flatMap { selectedID in
            rows.firstIndex {
                $0.id == selectedID
            }
        } ?? 0

        let offset: Int
        switch input {
        case .up:
            offset = -1
        case .down:
            offset = 1
        case .home:
            return rows.first?.id
        case .end:
            return rows.last?.id
        case .pageUp:
            offset = -max(pageSize, 1)
        case .pageDown:
            offset = max(pageSize, 1)
        }

        let index = min(max(currentIndex + offset, 0), rows.count - 1)
        return rows[index].id
    }

    static func contentLines<ID>(
        from rows: [RetortListRow<ID>],
        activeEditor: RetortListActiveEditor<ID>?
    ) -> [RetortListContentLine<ID>] where ID: Hashable {
        rows.flatMap {
            row in

            var lines = [
                RetortListContentLine(id: row.id, kind: .row),
            ]

            guard activeEditor?.id == row.id else {
                return lines
            }

            if let choices = activeEditor?.choices {
                lines += choices.indices.map {
                    RetortListContentLine(id: row.id, kind: .choice($0))
                }
            }
            else {
                lines.append(RetortListContentLine(id: row.id, kind: .textEditor))
                if activeEditor?.errorMessage != nil {
                    lines.append(RetortListContentLine(id: row.id, kind: .textEditorError))
                }
            }

            return lines
        }
    }

    static func targetLineRange<ID>(
        selection: ID?,
        activeEditor: RetortListActiveEditor<ID>?,
        rows: [RetortListRow<ID>]
    ) -> Range<Int>? where ID: Hashable {
        guard let selection else {
            return nil
        }

        let lines = contentLines(
            from: rows,
            activeEditor: activeEditor
        )

        if let activeEditor,
           activeEditor.id == selection {
            if activeEditor.choices != nil {
                return lineRange(
                    matching: RetortListContentLine(
                        id: selection,
                        kind: .choice(activeEditor.selectedChoiceIndex)
                    ),
                    in: lines
                )
            }

            if let editorLine = lines.firstIndex(
                of: RetortListContentLine(id: selection, kind: .textEditor)
            ) {
                if let errorLine = lines.firstIndex(
                    of: RetortListContentLine(id: selection, kind: .textEditorError)
                ) {
                    return editorLine..<(errorLine + 1)
                }

                return editorLine..<(editorLine + 1)
            }
        }

        return lineRange(
            matching: RetortListContentLine(id: selection, kind: .row),
            in: lines
        )
    }

    static func scrollY(
        currentY: Int,
        targetRange: Range<Int>?,
        viewportRows: Int,
        contentLineCount: Int
    ) -> Int {
        let viewportRows = max(viewportRows, 1)
        let maximumY = max(contentLineCount - viewportRows, 0)
        var nextY = min(max(currentY, 0), maximumY)

        guard let targetRange, !targetRange.isEmpty else {
            return nextY
        }

        if targetRange.lowerBound < nextY {
            nextY = targetRange.lowerBound
        }
        else if targetRange.upperBound > nextY + viewportRows {
            nextY = targetRange.upperBound - viewportRows
        }

        return min(max(nextY, 0), maximumY)
    }

    static func editorCursorPrefix(
        forDepth depth: Int,
        isSelected: Bool
    ) -> String {
        String(repeating: "  ", count: depth + 3)
            + (isSelected ? "❯ " : "  ")
    }

    private static func lineRange<ID>(
        matching target: RetortListContentLine<ID>,
        in lines: [RetortListContentLine<ID>]
    ) -> Range<Int>? where ID: Hashable {
        guard let index = lines.firstIndex(of: target) else {
            return nil
        }

        return index..<(index + 1)
    }
}

struct RetortListActiveEditor<ID> where ID: Hashable {

    var id: ID

    var draft: String

    var choices: [String]?

    var selectedChoiceIndex: Int

    var errorMessage: String?

    init(id: ID, editor: RetortListEditor) {
        self.id = id
        switch editor {
        case .text(let initialValue, _):
            self.draft = initialValue
            self.choices = nil
            self.selectedChoiceIndex = 0
        case .choice(let choices, let selectedIndex, _):
            self.draft = ""
            self.choices = choices
            if choices.isEmpty {
                self.selectedChoiceIndex = 0
            }
            else {
                self.selectedChoiceIndex = min(max(selectedIndex, 0), choices.count - 1)
            }
        }
    }
}
