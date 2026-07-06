import SwiftTUI

/// A wrapping horizontal flow for variable-width terminal views.
public struct RetortFlow<Content: View>: View {

    private let horizontalSpacing: Int

    private let verticalSpacing: Int

    private let content: Content

    /// Creates a flow layout that wraps children onto new rows when needed.
    ///
    /// - Parameters:
    ///   - horizontalSpacing: Blank columns inserted between adjacent children on the same row.
    ///   - verticalSpacing: Blank rows inserted between wrapped rows.
    ///   - content: The child views to arrange.
    public init(
        horizontalSpacing: Int = 1,
        verticalSpacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalSpacing = max(horizontalSpacing, 0)
        self.verticalSpacing = max(verticalSpacing, 0)
        self.content = content()
    }

    public var body: some View {
        RetortFlowLayout(
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        ) {
            content
        }
    }
}

private struct RetortFlowLayout: Layout {

    var horizontalSpacing: Int

    var verticalSpacing: Int

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> GeometrySize {
        let rows = rows(for: subviews, proposal: proposal)
        let contentWidth = rows.flatMap(\.items).map {
            $0.column + $0.size.columns
        }
        .max() ?? 0
        let contentHeight = rows.last.map {
            $0.row + $0.height
        } ?? 0

        return GeometrySize(
            columns: proposal.columns ?? contentWidth,
            rows: contentHeight
        )
    }

    func placeSubviews(
        in bounds: GeometryFrame,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for row in rows(for: subviews, proposal: proposal) {
            for item in row.items {
                subviews[item.index].place(
                    at: GeometryPoint(
                        column: bounds.origin.column + item.column,
                        row: bounds.origin.row + row.row
                    ),
                    proposal: .unspecified
                )
            }
        }
    }

    private func rows(
        for subviews: Subviews,
        proposal: ProposedViewSize
    ) -> [RetortFlowRow] {
        let maxColumns = proposal.columns
        var rows: [RetortFlowRow] = []
        var currentItems: [RetortFlowItem] = []
        var currentRow = 0
        var currentColumn = 0
        var currentHeight = 0

        func finishRow() {
            guard !currentItems.isEmpty else {
                return
            }

            rows.append(
                RetortFlowRow(
                    row: currentRow,
                    height: currentHeight,
                    items: currentItems
                )
            )
            currentRow += currentHeight + verticalSpacing
            currentItems = []
            currentColumn = 0
            currentHeight = 0
        }

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextColumn = currentItems.isEmpty
                ? 0
                : currentColumn + horizontalSpacing
            let nextEnd = nextColumn + size.columns

            if let maxColumns,
               !currentItems.isEmpty,
               nextEnd > maxColumns {
                finishRow()
            }

            let itemColumn = currentItems.isEmpty
                ? 0
                : currentColumn + horizontalSpacing
            currentItems.append(
                RetortFlowItem(
                    index: index,
                    column: itemColumn,
                    size: size
                )
            )
            currentColumn = itemColumn + size.columns
            currentHeight = max(currentHeight, size.rows)
        }

        finishRow()
        return rows
    }
}

private struct RetortFlowRow {

    var row: Int

    var height: Int

    var items: [RetortFlowItem]
}

private struct RetortFlowItem {

    var index: Int

    var column: Int

    var size: GeometrySize
}
