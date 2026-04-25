import SwiftUI

struct UnifiedDiffView: View {
    let rows: [DiffDisplayRow]
    let filePath: String
    var suppressLeadingTopBorder: Bool = false
    @State private var themeRevision = 0

    private var chunks: [DiffChunk] {
        buildDiffChunks(from: rows)
    }

    private var numberColumnWidth: CGFloat {
        lineNumberWidth(for: maxLineNumber(in: rows))
    }

    private var hunkChunkIndices: [Int: Int] {
        var result: [Int: Int] = [:]
        var hunkIdx = 0
        for (chunkIdx, chunk) in chunks.enumerated() {
            if case .divider = chunk {
                result[chunkIdx] = hunkIdx
                hunkIdx += 1
            }
        }
        return result
    }

    var body: some View {
        let indices = hunkChunkIndices
        LazyVStack(spacing: 0) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                switch chunk {
                case let .divider(text):
                    DiffSectionDivider(
                        text: text,
                        showsTopBorder: !(index == 0 && suppressLeadingTopBorder)
                    )
                    .id("diff-hunk-\(indices[index] ?? 0)")
                case let .codeBlock(blockRows):
                    unifiedCodeBlock(blockRows)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Unified diff, \(filePath)")
        .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
            themeRevision &+= 1
        }
    }

    private var gutterWidth: CGFloat {
        numberColumnWidth * 2 + 2 + DiffGutterNSView.prefixColumnWidth
    }

    private func unifiedCodeBlock(_ blockRows: [DiffDisplayRow]) -> some View {
        let height = CGFloat(blockRows.count) * diffLineHeight
        let metadata = buildDiffMetadata(from: blockRows)
        return HStack(alignment: .top, spacing: 0) {
            DiffGutterBridge(metadata: metadata, filePath: filePath, mode: .unified, columnWidth: numberColumnWidth)
                .frame(width: gutterWidth, height: height)

            ScrollView(.horizontal, showsIndicators: false) {
                DiffContentBridge(
                    rows: blockRows,
                    backgroundSide: .both
                )
                .frame(height: height)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}
