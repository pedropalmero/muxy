import SwiftUI

struct DiffViewerPane: View {
    @Bindable var state: DiffViewerTabState
    let focused: Bool
    let onFocus: () -> Void
    @FocusState private var paneFocused: Bool
    @State private var hunkCount = 0

    var body: some View {
        VStack(spacing: 0) {
            DiffViewerBreadcrumb(state: state)
            Rectangle().fill(MuxyTheme.border).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView([.vertical]) {
                    DiffBodyView(
                        isLoading: state.vcs.diffCache.isLoading(state.filePath),
                        error: state.vcs.diffCache.error(for: state.filePath),
                        diff: state.vcs.diffCache.diff(for: state.filePath),
                        filePath: state.filePath,
                        mode: state.mode,
                        onLoadFull: { state.refresh(forceFull: true) },
                        suppressLeadingTopBorder: true,
                        onHunkCount: { hunkCount = $0 }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onChange(of: state.currentHunkIndex) { _, idx in
                    proxy.scrollTo("diff-hunk-\(idx)", anchor: .top)
                }
            }
        }
        .background(MuxyTheme.bg)
        .contentShape(Rectangle())
        .focusable()
        .focused($paneFocused)
        .onKeyPress(phases: .down) { press in
            guard paneFocused else { return .ignored }
            return handleDiffKeyPress(press)
        }
        .simultaneousGesture(TapGesture().onEnded {
            paneFocused = true
            onFocus()
        })
        .onAppear { if focused { paneFocused = true } }
    }

    private func handleDiffKeyPress(_ press: KeyPress) -> KeyPress.Result {
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

private struct DiffViewerBreadcrumb: View {
    @Bindable var state: DiffViewerTabState

    private var loadedDiff: DiffCache.LoadedDiff? {
        state.vcs.diffCache.diff(for: state.filePath)
    }

    var body: some View {
        HStack(spacing: UIMetrics.spacing3) {
            FileDiffIcon()
                .stroke(MuxyTheme.fgDim, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: UIMetrics.scaled(11), height: UIMetrics.scaled(11))

            Text(state.filePath)
                .font(.system(size: UIMetrics.fontFootnote))
                .foregroundStyle(MuxyTheme.fgMuted)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            if state.isStaged {
                Text("Staged")
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
                    .padding(.horizontal, UIMetrics.scaled(5))
                    .padding(.vertical, UIMetrics.scaled(1))
                    .background(MuxyTheme.surface, in: Capsule())
            }

            if let diff = loadedDiff {
                if diff.additions > 0 {
                    Text("+\(diff.additions)")
                        .font(.system(size: UIMetrics.fontFootnote, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MuxyTheme.diffAddFg)
                }
                if diff.deletions > 0 {
                    Text("-\(diff.deletions)")
                        .font(.system(size: UIMetrics.fontFootnote, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MuxyTheme.diffRemoveFg)
                }
            }

            Spacer()

            modeToggle

            IconButton(symbol: "arrow.clockwise", size: 11, accessibilityLabel: "Refresh Diff") {
                state.refresh(forceFull: false)
            }
            .help("Refresh")
        }
        .padding(.horizontal, UIMetrics.spacing5)
        .frame(height: UIMetrics.scaled(32))
        .background(MuxyTheme.bg)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton(.split, symbol: "rectangle.split.2x1", tooltip: "Side by side")
            modeButton(.unified, symbol: "rectangle", tooltip: "Inline")
        }
        .background(MuxyTheme.surface, in: RoundedRectangle(cornerRadius: UIMetrics.radiusSM))
        .overlay(RoundedRectangle(cornerRadius: UIMetrics.radiusSM).stroke(MuxyTheme.border, lineWidth: 1))
    }

    private func modeButton(_ mode: VCSTabState.ViewMode, symbol: String, tooltip: String) -> some View {
        let selected = state.mode == mode
        return Button {
            state.mode = mode
        } label: {
            Image(systemName: symbol)
                .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                .foregroundStyle(selected ? MuxyTheme.fg : MuxyTheme.fgMuted)
                .frame(width: UIMetrics.scaled(22), height: UIMetrics.controlSmall)
                .background(selected ? MuxyTheme.bg : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
