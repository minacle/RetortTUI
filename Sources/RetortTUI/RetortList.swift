import SwiftTUI

/// The result of committing an inline list editor.
public enum RetortListCommitResult: Equatable, Sendable {

    case accepted

    case rejected(String)
}

/// The currently active inline list editor state.
public enum RetortListEditingState<ID>: Equatable where ID: Hashable {

    case text(id: ID, draft: String)

    case choice(id: ID, selectedIndex: Int, selectedChoice: String)
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
            parse: { Value($0) },
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

    private let editing: Binding<ID?>?

    private var onEditingChange: (RetortListEditingState<ID>?) -> Void

    public init(
        selection: FocusState<ID?>.Binding,
        @RetortListItemBuilder<ID> content: () -> [RetortListItem<ID>]
    ) {
        self.selection = selection
        self.editing = nil
        self.onEditingChange = { _ in }
        self.items = content()
    }

    public init(
        selection: FocusState<ID?>.Binding,
        editing: Binding<ID?>,
        @RetortListItemBuilder<ID> content: () -> [RetortListItem<ID>]
    ) {
        self.selection = selection
        self.editing = editing
        self.onEditingChange = { _ in }
        self.items = content()
    }

    public var body: some View {
        GeometryReader {
            proxy in

            RetortListStorage(
                items: items,
                selection: selection,
                editing: editing,
                onEditingChange: onEditingChange,
                viewportRows: proxy.rows
            )
        }
    }

    public func onEditingChange(
        _ action: @escaping (RetortListEditingState<ID>?) -> Void
    ) -> Self {
        var copy = self
        copy.onEditingChange = action
        return copy
    }
}

private struct RetortListStorage<ID>: View where ID: Hashable {

    let items: [RetortListItem<ID>]

    let selection: FocusState<ID?>.Binding

    let editing: Binding<ID?>?

    let onEditingChange: (RetortListEditingState<ID>?) -> Void

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
        .onChange(of: requestedEditingID, initial: true) {
            synchronizeEditingRequest()
        }
        .onChange(of: editorDraft) {
            notifyTextDraftChange()
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
        let isEditing = activeEditor?.id == row.id
        let isSelected = selection.wrappedValue == row.id && !isEditing
        let isHighlighted = selection.wrappedValue == row.id || isEditing
        let leadingAccessory = row.item.configuration.leadingAccessory
        let subtitle = row.item.configuration.subtitle

        RetortListRowLayout(
            depth: row.depth,
            isGroup: row.isGroup,
            reservesDisclosureSpace: row.reservesDisclosureSpace,
            hasLeadingAccessory: leadingAccessory != nil,
            hasSubtitle: subtitle != nil
        ) {
            Text(rowCursor(isSelected: isSelected))
                .bold(isSelected)
            Text(row.disclosureMarker)
            if let leadingAccessory {
                HStack(spacing: 0) {
                    leadingAccessory
                    Text(" ")
                }
            }
            row.item.configuration.title
                .bold(isHighlighted)
            if let subtitle {
                HStack(spacing: 0) {
                    Text("  ")
                    subtitle
                        .color(.brightBlack)
                }
            }
        }
        .focusable(!isTextEditorActive(for: row))
        .focused(selection, equals: row.id)
        .onTapGesture {
            selection.wrappedValue = row.id
        }
    }

    @ViewBuilder
    private func textEditorView(_ row: RetortListRow<ID>) -> some View {
        let leadingAccessory = row.item.configuration.leadingAccessory

        RetortListEditorLineLayout(
            depth: row.depth,
            isGroup: row.isGroup,
            reservesDisclosureSpace: row.reservesDisclosureSpace,
            hasLeadingAccessory: leadingAccessory != nil
        ) {
            Text(rowCursor(isSelected: true))
                .bold()
            if let leadingAccessory {
                HStack(spacing: 0) {
                    leadingAccessory
                    Text(" ")
                }
            }
            TextField(
                "",
                text: $editorDraft
            )
            .focused($isTextEditorFocused)
            .onSubmit {
                commitActiveEditor(for: row.item)
                scrollSelectionIntoView()
            }
        }

        if let errorMessage = activeEditor?.errorMessage {
            RetortListEditorLineLayout(
                depth: row.depth,
                isGroup: row.isGroup,
                reservesDisclosureSpace: row.reservesDisclosureSpace,
                hasLeadingAccessory: leadingAccessory != nil
            ) {
                Text(rowCursor(isSelected: false))
                if let leadingAccessory {
                    HStack(spacing: 0) {
                        leadingAccessory
                        Text(" ")
                    }
                }
                Text("Error: \(errorMessage)")
                    .color(.red)
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

            let leadingAccessory = row.item.configuration.leadingAccessory

            RetortListEditorLineLayout(
                depth: row.depth,
                isGroup: row.isGroup,
                reservesDisclosureSpace: row.reservesDisclosureSpace,
                hasLeadingAccessory: leadingAccessory != nil
            ) {
                Text(rowCursor(isSelected: isSelected))
                    .bold(isSelected)
                if let leadingAccessory {
                    HStack(spacing: 0) {
                        leadingAccessory
                        Text(" ")
                    }
                }
                Text(choices[index])
                    .bold(isSelected)
            }
            .onTapGesture {
                selectChoice(index)
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

        let rows = visibleRows
        selection.wrappedValue = RetortListModel.movedSelection(
            selection.wrappedValue,
            input: input,
            rows: rows,
            pageSize: RetortListModel.pageSize(
                viewportRows: viewportRows,
                itemCount: rows.count
            )
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

        closeEditor(updateEditingRequest: true)
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
        openEditor(editor, for: id, updateEditingRequest: true)
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
            closeEditor(updateEditingRequest: true)
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
        let nextIndex: Int
        switch key {
        case .upArrow, .leftArrow:
            nextIndex = max(index - 1, 0)
        case .downArrow, .rightArrow:
            nextIndex = min(index + 1, choices.count - 1)
        case .home:
            nextIndex = 0
        case .end:
            nextIndex = choices.count - 1
        case .pageUp:
            nextIndex = max(index - choicePageSize(for: choices), 0)
        case .pageDown:
            nextIndex = min(
                index + choicePageSize(for: choices),
                choices.count - 1
            )
        default:
            return
        }

        guard nextIndex != index else {
            return
        }

        activeEditor.selectedChoiceIndex = nextIndex
        self.activeEditor = activeEditor
        notifyEditingChange()
    }

    private func selectChoice(_ index: Int) {
        guard var activeEditor,
              let choices = activeEditor.choices,
              choices.indices.contains(index),
              activeEditor.selectedChoiceIndex != index else {
            return
        }

        activeEditor.selectedChoiceIndex = index
        self.activeEditor = activeEditor
        notifyEditingChange()
    }

    private var requestedEditingID: ID? {
        editing?.wrappedValue
    }

    private var currentEditingState: RetortListEditingState<ID>? {
        guard let activeEditor else {
            return nil
        }

        guard let choices = activeEditor.choices else {
            return .text(id: activeEditor.id, draft: editorDraft)
        }

        guard choices.indices.contains(activeEditor.selectedChoiceIndex) else {
            return nil
        }

        return .choice(
            id: activeEditor.id,
            selectedIndex: activeEditor.selectedChoiceIndex,
            selectedChoice: choices[activeEditor.selectedChoiceIndex]
        )
    }

    private func synchronizeEditingRequest() {
        guard let editing else {
            return
        }

        guard let id = editing.wrappedValue else {
            closeEditor(updateEditingRequest: false)
            return
        }

        if activeEditor?.id == id {
            return
        }

        guard let row = visibleRows.first(where: { $0.id == id }),
              let editor = row.item.configuration.editor else {
            updateEditingRequest(nil)
            return
        }

        selection.wrappedValue = id
        openEditor(editor, for: id, updateEditingRequest: false)
        scrollSelectionIntoView()
    }

    private func openEditor(
        _ editor: RetortListEditor,
        for id: ID,
        updateEditingRequest: Bool
    ) {
        let nextEditor = RetortListActiveEditor(id: id, editor: editor)
        activeEditor = nextEditor
        editorDraft = nextEditor.draft
        switch editor {
        case .text:
            isTextEditorFocused = true
        case .choice:
            isTextEditorFocused = false
        }
        notifyEditingChange()
        if updateEditingRequest {
            self.updateEditingRequest(id)
        }
    }

    private func closeEditor(updateEditingRequest: Bool) {
        let wasEditing = activeEditor != nil
        activeEditor = nil
        editorDraft = ""
        isTextEditorFocused = false
        if wasEditing {
            notifyEditingChange()
        }
        if updateEditingRequest {
            self.updateEditingRequest(nil)
        }
    }

    private func updateEditingRequest(_ id: ID?) {
        guard let editing,
              editing.wrappedValue != id else {
            return
        }

        editing.wrappedValue = id
    }

    private func notifyEditingChange() {
        onEditingChange(currentEditingState)
    }

    private func notifyTextDraftChange() {
        guard var activeEditor,
              activeEditor.choices == nil,
              activeEditor.draft != editorDraft else {
            return
        }

        activeEditor.draft = editorDraft
        self.activeEditor = activeEditor
        notifyEditingChange()
    }

    private func choicePageSize(for choices: [String]) -> Int {
        RetortListModel.pageSize(
            viewportRows: viewportRows,
            itemCount: choices.count
        )
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
        let contentLineCount = RetortListModel.contentLines(
            from: rows,
            activeEditor: activeEditor
        )
        .count
        let nextY = RetortListModel.scrollY(
            currentY: scrollPosition.y ?? 0,
            targetRange: RetortListModel.targetLineRange(
                selection: selection.wrappedValue,
                activeEditor: activeEditor,
                rows: rows
            ),
            viewportRows: RetortListModel.pageSize(
                viewportRows: viewportRows,
                itemCount: contentLineCount
            ),
            contentLineCount: contentLineCount
        )

        scrollPosition.scrollTo(y: nextY)
    }

}

struct RetortListRow<ID>: Identifiable where ID: Hashable {

    var id: ID

    var depth: Int

    var item: RetortListItem<ID>

    var isCollapsed: Bool

    var reservesDisclosureSpace: Bool

    var isGroup: Bool {
        !item.configuration.children.isEmpty
    }

    var disclosureMarker: String {
        guard isGroup else {
            return ""
        }

        return isCollapsed ? "▸ " : "▾ "
    }
}

private struct RetortListRowLayout: Layout {

    var depth: Int

    var isGroup: Bool

    var reservesDisclosureSpace: Bool

    var hasLeadingAccessory: Bool

    var hasSubtitle: Bool

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> GeometrySize {
        let placements = placements(for: subviews)
        let contentWidth = placements.map {
            $0.column + $0.size.columns
        }
        .max() ?? 0
        let contentHeight = placements.map(\.size.rows).max() ?? 0

        return GeometrySize(
            columns: proposal.columns ?? contentWidth,
            rows: max(contentHeight, 1)
        )
    }

    func placeSubviews(
        in bounds: GeometryFrame,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for placement in placements(for: subviews) {
            subviews[placement.index].place(
                at: GeometryPoint(
                    column: bounds.origin.column + placement.column,
                    row: bounds.origin.row
                )
            )
        }
    }

    private func placements(for subviews: Subviews) -> [RetortListRowLayoutPlacement] {
        guard subviews.count >= 3 else {
            return []
        }

        let cursorIndex = 0
        let disclosureIndex = 1
        let leadingAccessoryIndex = hasLeadingAccessory ? 2 : nil
        let titleIndex = hasLeadingAccessory ? 3 : 2
        let subtitleIndex = hasSubtitle ? titleIndex + 1 : nil

        guard subviews.indices.contains(titleIndex) else {
            return []
        }

        let cursorSize = subviews[cursorIndex].sizeThatFits(.unspecified)
        let disclosureSize = subviews[disclosureIndex].sizeThatFits(.unspecified)
        let leadingAccessorySize = leadingAccessoryIndex.map {
            subviews[$0].sizeThatFits(.unspecified)
        } ?? GeometrySize()
        let titleSize = subviews[titleIndex].sizeThatFits(.unspecified)
        let subtitleSize = subtitleIndex.map {
            subviews[$0].sizeThatFits(.unspecified)
        } ?? GeometrySize()

        let columns = RetortListRowColumns(
            cursorWidth: cursorSize.columns,
            depth: depth,
            isGroup: isGroup,
            reservesDisclosureSpace: reservesDisclosureSpace,
            disclosureWidth: disclosureSize.columns,
            leadingAccessoryWidth: leadingAccessorySize.columns
        )

        var placements = [
            RetortListRowLayoutPlacement(
                index: cursorIndex,
                column: 0,
                size: cursorSize
            ),
            RetortListRowLayoutPlacement(
                    index: disclosureIndex,
                    column: columns.disclosureColumn,
                    size: disclosureSize
                ),
        ]

        if let leadingAccessoryIndex {
            placements.append(
                RetortListRowLayoutPlacement(
                    index: leadingAccessoryIndex,
                    column: columns.leadingAccessoryColumn,
                    size: leadingAccessorySize
                )
            )
        }

        placements.append(
            RetortListRowLayoutPlacement(
                index: titleIndex,
                column: columns.titleColumn,
                size: titleSize
            )
        )

        if let subtitleIndex {
            placements.append(
                RetortListRowLayoutPlacement(
                    index: subtitleIndex,
                    column: columns.titleColumn + titleSize.columns,
                    size: subtitleSize
                )
            )
        }

        return placements
    }
}

private struct RetortListEditorLineLayout: Layout {

    var depth: Int

    var isGroup: Bool

    var reservesDisclosureSpace: Bool

    var hasLeadingAccessory: Bool

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> GeometrySize {
        let placements = placements(for: subviews, proposal: proposal)
        let contentWidth = placements.map {
            $0.column + $0.size.columns
        }
        .max() ?? 0
        let contentHeight = placements.map(\.size.rows).max() ?? 0

        return GeometrySize(
            columns: proposal.columns ?? contentWidth,
            rows: max(contentHeight, 1)
        )
    }

    func placeSubviews(
        in bounds: GeometryFrame,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for placement in placements(for: subviews, proposal: proposal) {
            subviews[placement.index].place(
                at: GeometryPoint(
                    column: bounds.origin.column + placement.column,
                    row: bounds.origin.row
                ),
                proposal: placement.proposal
            )
        }
    }

    private func placements(
        for subviews: Subviews,
        proposal: ProposedViewSize
    ) -> [RetortListEditorLineLayoutPlacement] {
        let cursorIndex = 0
        let leadingAccessoryIndex = hasLeadingAccessory ? 1 : nil
        let contentIndex = hasLeadingAccessory ? 2 : 1

        guard subviews.indices.contains(contentIndex) else {
            return []
        }

        let cursorSize = subviews[cursorIndex].sizeThatFits(.unspecified)
        let leadingAccessorySize = leadingAccessoryIndex.map {
            subviews[$0].sizeThatFits(.unspecified)
        } ?? GeometrySize()
        let columns = RetortListRowColumns(
            cursorWidth: cursorSize.columns,
            depth: depth,
            isGroup: isGroup,
            reservesDisclosureSpace: reservesDisclosureSpace,
            disclosureWidth: 0,
            leadingAccessoryWidth: leadingAccessorySize.columns
        )
        let cursorColumn = columns.titleColumn + 2
        let contentColumn = cursorColumn + cursorSize.columns
        let contentProposal = ProposedViewSize(
            columns: proposal.columns.map {
                max($0 - contentColumn, 0)
            },
            rows: proposal.rows
        )
        let contentSize = subviews[contentIndex].sizeThatFits(contentProposal)

        return [
            RetortListEditorLineLayoutPlacement(
                index: cursorIndex,
                column: cursorColumn,
                size: cursorSize,
                proposal: .unspecified
            ),
            RetortListEditorLineLayoutPlacement(
                index: contentIndex,
                column: contentColumn,
                size: contentSize,
                proposal: contentProposal
            ),
        ]
    }
}

private nonisolated struct RetortListRowColumns {

    var cursorWidth: Int

    var depth: Int

    var isGroup: Bool

    var reservesDisclosureSpace: Bool

    var disclosureWidth: Int

    var leadingAccessoryWidth: Int

    var disclosureColumn: Int {
        cursorWidth + indentWidth
    }

    var leadingAccessoryColumn: Int {
        if isGroup || reservesDisclosureSpace {
            return disclosureColumn + effectiveDisclosureWidth
        }

        return max(cursorWidth, targetTitleColumn - leadingAccessoryWidth)
    }

    var titleColumn: Int {
        if isGroup || reservesDisclosureSpace {
            return disclosureColumn + effectiveDisclosureWidth + leadingAccessoryWidth
        }

        return leadingAccessoryColumn + leadingAccessoryWidth
    }

    private var indentWidth: Int {
        depth * 2
    }

    private var targetTitleColumn: Int {
        cursorWidth + indentWidth
    }

    private var effectiveDisclosureWidth: Int {
        max(disclosureWidth, reservesDisclosureSpace ? 2 : 0)
    }
}

private struct RetortListRowLayoutPlacement {

    var index: Int

    var column: Int

    var size: GeometrySize
}

private struct RetortListEditorLineLayoutPlacement {

    var index: Int

    var column: Int

    var size: GeometrySize

    var proposal: ProposedViewSize
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
        let reservesDisclosureSpace = containsGroup(items)
        return items.flatMap {
            rows(
                for: $0,
                depth: 0,
                collapsedIDs: collapsedIDs,
                reservesDisclosureSpace: reservesDisclosureSpace
            )
        }
    }

    static func rows<ID>(
        for item: RetortListItem<ID>,
        depth: Int,
        collapsedIDs: Set<ID>,
        reservesDisclosureSpace: Bool
    ) -> [RetortListRow<ID>] where ID: Hashable {
        let isCollapsed = collapsedIDs.contains(item.configuration.id)
        let row = RetortListRow(
            id: item.configuration.id,
            depth: depth,
            item: item,
            isCollapsed: isCollapsed,
            reservesDisclosureSpace: reservesDisclosureSpace
        )

        guard !isCollapsed else {
            return [row]
        }

        let children = item.configuration.children
        let childrenReserveDisclosureSpace = containsGroup(children)
        return [row] + children.flatMap {
            rows(
                for: $0,
                depth: depth + 1,
                collapsedIDs: collapsedIDs,
                reservesDisclosureSpace: childrenReserveDisclosureSpace
            )
        }
    }

    private static func containsGroup<ID>(
        _ items: [RetortListItem<ID>]
    ) -> Bool where ID: Hashable {
        items.contains {
            !$0.configuration.children.isEmpty
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

    static func pageSize(
        viewportRows: Int,
        itemCount: Int
    ) -> Int {
        let itemCount = max(itemCount, 1)
        guard viewportRows > 0 else {
            return itemCount
        }

        return min(max(viewportRows, 1), itemCount)
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
