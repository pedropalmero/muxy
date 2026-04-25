import SwiftUI

struct CommitDiffViewerPane: View {
    @Bindable var state: CommitDiffViewerTabState
    let focused: Bool
    let onFocus: () -> Void
    @FocusState private var paneFocused: Bool
    @State private var hunkCount = 0
    @State private var fileListHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            commitBreadcrumb
            Rectangle().fill(MuxyTheme.border).frame(height: 1)
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    fileListPanel
                        .frame(height: fileListHeight)
                    dividerHandle(totalHeight: geometry.size.height)
                    diffPanel
                }
            }
        }
        .background(MuxyTheme.bg)
        .contentShape(Rectangle())
        .focusable()
        .focused($paneFocused)
        .onKeyPress(phases: .down) { press in
            guard paneFocused else { return .ignored }
            return handleKeyPress(press)
        }
        .simultaneousGesture(TapGesture().onEnded {
            paneFocused = true
            onFocus()
        })
        .onAppear { if focused { paneFocused = true } }
    }

    private var commitBreadcrumb: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgDim)

            Text(state.commit.shortHash)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MuxyTheme.fgMuted)

            Text(state.commit.subject)
                .font(.system(size: 11))
                .foregroundStyle(MuxyTheme.fg)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if state.totalAdditions > 0 {
                Text("+\(state.totalAdditions)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MuxyTheme.diffAddFg)
            }

            if state.totalDeletions > 0 {
                Text("-\(state.totalDeletions)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MuxyTheme.diffRemoveFg)
            }

            modeToggle

            IconButton(symbol: "arrow.clockwise", size: 11, accessibilityLabel: "Refresh") {
                state.loadFiles(forceFull: false)
            }
            .help("Refresh")
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(MuxyTheme.bg)
    }

    private var fileListPanel: some View {
        Group {
            if state.isLoadingFiles {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = state.filesError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(MuxyTheme.diffRemoveFg)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(state.files) { file in
                                fileRow(file)
                                    .id("commit-file-\(file.path)")
                            }
                        }
                    }
                    .onChange(of: state.selectedFilePath) { _, path in
                        guard let path else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo("commit-file-\(path)", anchor: .center)
                        }
                    }
                }
            }
        }
        .background(MuxyTheme.bg)
    }

    private func fileRow(_ file: CommitChangedFile) -> some View {
        let isSelected = state.selectedFilePath == file.path
        return Button {
            state.selectFile(file.path)
        } label: {
            HStack(spacing: 6) {
                Text(file.statusLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor(file.status))
                    .frame(width: 12, alignment: .center)

                Text((file.path as NSString).lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundStyle(MuxyTheme.fg)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let oldPath = file.oldPath {
                    Text("← \((oldPath as NSString).lastPathComponent)")
                        .font(.system(size: 10))
                        .foregroundStyle(MuxyTheme.fgDim)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if file.isBinary {
                    Text("Binary")
                        .font(.system(size: 10))
                        .foregroundStyle(MuxyTheme.fgDim)
                } else {
                    HStack(spacing: 4) {
                        if file.additions > 0 {
                            Text("+\(file.additions)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(MuxyTheme.diffAddFg)
                        }
                        if file.deletions > 0 {
                            Text("-\(file.deletions)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(MuxyTheme.diffRemoveFg)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isSelected ? MuxyTheme.hover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dividerHandle(totalHeight: CGFloat) -> some View {
        Rectangle()
            .fill(MuxyTheme.border)
            .frame(height: 4)
            .background(MuxyTheme.surface)
            .onHover { on in
                if on { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newHeight = fileListHeight + value.translation.height
                        fileListHeight = min(max(newHeight, 60), totalHeight - 80)
                    }
            )
    }

    private var diffPanel: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical]) {
                if let filePath = state.selectedFilePath {
                    let file = state.files.first(where: { $0.path == filePath })
                    DiffBodyView(
                        isLoading: state.loadingPaths.contains(filePath),
                        error: state.errorsByPath[filePath],
                        diff: state.diffsByPath[filePath],
                        filePath: filePath,
                        mode: state.mode,
                        onLoadFull: { state.loadDiff(for: filePath, forceFull: true) },
                        suppressLeadingTopBorder: true,
                        onHunkCount: { hunkCount = $0 }
                    )
                    .disabled(file?.isBinary == true)
                } else if !state.isLoadingFiles {
                    Text("Select a file to view its diff")
                        .font(.system(size: 12))
                        .foregroundStyle(MuxyTheme.fgMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: state.currentHunkIndex) { _, idx in
                proxy.scrollTo("diff-hunk-\(idx)", anchor: .top)
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton(.split, symbol: "rectangle.split.2x1", tooltip: "Side by side")
            modeButton(.unified, symbol: "rectangle", tooltip: "Inline")
        }
        .background(MuxyTheme.surface, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(MuxyTheme.border, lineWidth: 1))
    }

    private func modeButton(_ mode: VCSTabState.ViewMode, symbol: String, tooltip: String) -> some View {
        let selected = state.mode == mode
        return Button {
            state.mode = mode
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(selected ? MuxyTheme.fg : MuxyTheme.fgMuted)
                .frame(width: 22, height: 20)
                .background(selected ? MuxyTheme.bg : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func statusColor(_ status: CommitChangedFile.Status) -> Color {
        switch status {
        case .added: MuxyTheme.diffAddFg
        case .deleted: MuxyTheme.diffRemoveFg
        case .modified: MuxyTheme.accent
        case .renamed,
             .copied: MuxyTheme.diffAddFg
        case .typeChanged,
             .unknown: MuxyTheme.fgMuted
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let rawKey = String(press.key.character)
        let normalizedKey = KeyCombo.normalized(key: rawKey)
        var flags: UInt = 0
        if press.modifiers.contains(.command) { flags |= NSEvent.ModifierFlags.command.rawValue }
        if press.modifiers.contains(.shift) { flags |= NSEvent.ModifierFlags.shift.rawValue }
        if press.modifiers.contains(.control) { flags |= NSEvent.ModifierFlags.control.rawValue }
        if press.modifiers.contains(.option) { flags |= NSEvent.ModifierFlags.option.rawValue }
        let combo = KeyCombo(key: normalizedKey, modifiers: flags)
        guard let action = KeyBindingStore.shared.action(for: combo, scopes: [.vcsPanel]) else {
            return .ignored
        }
        switch action {
        case .vcsNextRow:
            state.selectNextFile()
            return .handled
        case .vcsPrevRow:
            state.selectPrevFile()
            return .handled
        case .vcsNextHunk:
            state.navigateToHunk(delta: 1, hunkCount: hunkCount)
            return .handled
        case .vcsPrevHunk:
            state.navigateToHunk(delta: -1, hunkCount: hunkCount)
            return .handled
        default:
            return .ignored
        }
    }
}
