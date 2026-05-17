import Foundation
import Testing

@testable import Muxy

@Suite("VCSTabState Navigation")
@MainActor
struct VCSTabStateNavigationTests {
    private func makeState(
        staged: [String] = [],
        unstaged: [String] = [],
        commits: [String] = []
    ) -> VCSTabState {
        let state = VCSTabState(projectPath: "/tmp/muxy-test-\(UUID().uuidString)")
        state.files = staged.map { makeStaged($0) } + unstaged.map { makeUnstaged($0) }
        state.commits = commits.enumerated().map { idx, subject in
            GitCommit(
                hash: "hash\(idx)",
                shortHash: "h\(idx)",
                subject: subject,
                authorName: "Author",
                authorDate: Date(),
                refs: [],
                parentHashes: []
            )
        }
        state.changesVisible = true
        state.historyVisible = true
        state.pullRequestsVisible = false
        return state
    }

    private func makeStaged(_ path: String) -> GitStatusFile {
        GitStatusFile(path: path, oldPath: nil, xStatus: "M", yStatus: " ", additions: nil, deletions: nil, isBinary: false)
    }

    private func makeUnstaged(_ path: String) -> GitStatusFile {
        GitStatusFile(path: path, oldPath: nil, xStatus: " ", yStatus: "M", additions: nil, deletions: nil, isBinary: false)
    }

    private func makePartiallyStaged(_ path: String) -> GitStatusFile {
        GitStatusFile(path: path, oldPath: nil, xStatus: "M", yStatus: "M", additions: nil, deletions: nil, isBinary: false)
    }

    @Test("selectFirstRow focuses first section when no staged files")
    func selectFirstRowNoStaged() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.selectFirstRow()
        #expect(state.focus == .section(.changes))
    }

    @Test("selectFirstRow focuses staged section when staged files exist")
    func selectFirstRowWithStaged() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"])
        state.selectFirstRow()
        #expect(state.focus == .section(.staged))
    }

    @Test("bootstrapFocusIfNeeded waits for initial file load")
    func bootstrapFocusWaitsForInitialFileLoad() {
        let state = makeState()
        state.bootstrapFocusIfNeeded()
        #expect(state.focus == nil)

        state.files = [makeStaged("s.swift"), makeUnstaged("u.swift")]
        state.bootstrapFocusIfNeeded()
        #expect(state.focus == .section(.staged))
    }

    @Test("files update moves focused path to its new section")
    func filesUpdateMovesFocusedPathToNewSection() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")

        state.files = [makeStaged("a.swift")]

        #expect(state.focus == .file(section: .staged, path: "a.swift"))
    }

    @Test("files update keeps partially staged focus in current section")
    func filesUpdateKeepsPartialFocusInCurrentSection() {
        let state = makeState()
        state.files = [makePartiallyStaged("a.swift")]
        state.focus = .file(section: .changes, path: "a.swift")

        state.files = [makePartiallyStaged("a.swift")]

        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("files update moves removed focused file to neighboring row")
    func filesUpdateMovesRemovedFocusToNeighboringRow() {
        let state = makeState(unstaged: ["a.swift", "b.swift", "c.swift"])
        state.focus = .file(section: .changes, path: "b.swift")

        state.files = [makeUnstaged("a.swift"), makeUnstaged("c.swift")]

        #expect(state.focus == .file(section: .changes, path: "c.swift"))
    }

    @Test("files update moves removed section focus to next visible section")
    func filesUpdateMovesRemovedSectionFocusToNextVisibleSection() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"])
        state.focus = .file(section: .staged, path: "s.swift")

        state.files = [makeUnstaged("u.swift")]

        #expect(state.focus == .section(.changes))
    }

    @Test("selectNextRow from section header enters first row when expanded")
    func selectNextRowFromSectionHeader() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.focus = .section(.changes)
        state.selectNextRow()
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("selectNextRow from folder mode section enters visible folder first")
    func selectNextRowFolderModeEntersFolder() {
        let state = makeState(unstaged: ["Sources/App/a.swift"])
        state.fileListMode = .folders
        state.focus = .section(.changes)

        state.selectNextRow()

        #expect(state.focus == .folder(section: .changes, path: "Sources/App"))
    }

    @Test("folder mode navigation omits files inside collapsed folders")
    func folderModeNavigationOmitsCollapsedChildren() {
        let state = makeState(unstaged: ["Sources/App/a.swift"])
        state.fileListMode = .folders
        state.historyVisible = false
        state.focus = .folder(section: .changes, path: "Sources/App")

        state.selectNextRow()

        #expect(state.focus == .folder(section: .changes, path: "Sources/App"))
    }

    @Test("folder mode navigation enters expanded folder children")
    func folderModeNavigationEntersExpandedFolderChildren() {
        let state = makeState(unstaged: ["Sources/App/a.swift"])
        state.fileListMode = .folders
        state.toggleFolderExpanded("Sources/App", section: .changes)
        state.focus = .folder(section: .changes, path: "Sources/App")

        state.selectNextRow()

        #expect(state.focus == .file(section: .changes, path: "Sources/App/a.swift"))
    }

    @Test("selectNextRow from section header goes to next section when collapsed")
    func selectNextRowFromCollapsedSectionHeader() {
        let state = makeState(unstaged: ["a.swift"], commits: ["C1"])
        state.changesCollapsed = true
        state.focus = .section(.changes)
        state.selectNextRow()
        #expect(state.focus == .section(.history))
    }

    @Test("selectNextRow advances within the same section")
    func selectNextRowWithinSection() {
        let state = makeState(unstaged: ["a.swift", "b.swift", "c.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.selectNextRow()
        #expect(state.focus == .file(section: .changes, path: "b.swift"))
    }

    @Test("selectNextRow goes to next section header at end of section")
    func selectNextRowWrapsToNextSection() {
        let state = makeState(unstaged: ["a.swift"], commits: ["Initial commit"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.selectNextRow()
        #expect(state.focus == .section(.history))
    }

    @Test("selectNextRow stays at last row when at end of last section")
    func selectNextRowAtLastRow() {
        let state = makeState(unstaged: ["a.swift"])
        state.historyVisible = false
        state.focus = .file(section: .changes, path: "a.swift")
        state.selectNextRow()
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("selectPrevRow moves backward within section")
    func selectPrevRowWithinSection() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.focus = .file(section: .changes, path: "b.swift")
        state.selectPrevRow()
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("selectPrevRow from first row goes back to section header")
    func selectPrevRowFromFirstRowGoesToHeader() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.selectPrevRow()
        #expect(state.focus == .section(.changes))
    }

    @Test("selectPrevRow from section header goes to prev section header")
    func selectPrevRowWrapsToPrevSection() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"])
        state.changesCollapsed = false
        state.stagedCollapsed = true
        state.focus = .section(.changes)
        state.selectPrevRow()
        #expect(state.focus == .section(.staged))
    }

    @Test("cycleSectionForward moves to next section header")
    func cycleSectionForward() {
        let state = makeState(unstaged: ["a.swift"], commits: ["C1"])
        state.focus = .section(.changes)
        state.cycleSectionForward()
        #expect(state.focus == .section(.history))
    }

    @Test("cycleSectionForward wraps around to first section")
    func cycleSectionForwardWraps() {
        let state = makeState(unstaged: ["a.swift"], commits: ["C1"])
        state.historyVisible = true
        state.changesVisible = true
        state.focus = .section(.history)
        state.cycleSectionForward()
        #expect(state.focus == .section(.changes))
    }

    @Test("cycleSectionBackward moves to previous section header")
    func cycleSectionBackward() {
        let state = makeState(unstaged: ["a.swift"], commits: ["C1"])
        state.focus = .section(.history)
        state.cycleSectionBackward()
        #expect(state.focus == .section(.changes))
    }

    @Test("cyclePanelTargetForward includes commit message after visible sections")
    func cyclePanelTargetForwardIncludesCommitMessage() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"], commits: ["C1"])
        state.focus = .section(.history)
        state.cyclePanelTargetForward()
        #expect(state.focus == .commitMessage)

        state.cyclePanelTargetForward()
        #expect(state.focus == .section(.staged))
    }

    @Test("cyclePanelTargetBackward includes commit message before wrapping to sections")
    func cyclePanelTargetBackwardIncludesCommitMessage() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"], commits: ["C1"])
        state.focus = .section(.staged)
        state.cyclePanelTargetBackward()
        #expect(state.focus == .commitMessage)

        state.cyclePanelTargetBackward()
        #expect(state.focus == .section(.history))
    }

    @Test("cyclePanelTargetForward omits hidden staged section")
    func cyclePanelTargetForwardOmitsHiddenStagedSection() {
        let state = makeState(unstaged: ["u.swift"])
        state.historyVisible = false
        state.focus = .section(.changes)
        state.cyclePanelTargetForward()
        #expect(state.focus == .commitMessage)

        state.cyclePanelTargetForward()
        #expect(state.focus == .section(.changes))
    }

    @Test("cyclePanelTargetForward can omit commit message")
    func cyclePanelTargetForwardOmitsCommitMessageWhenRequested() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"], commits: ["C1"])
        state.focus = .section(.history)
        state.cyclePanelTargetForward(includeCommitMessage: false)
        #expect(state.focus == .section(.staged))
    }

    @Test("stageFocused stages the focused changes file")
    func stageFocusedStagesFile() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.stageFocused()
    }

    @Test("stageFocused does nothing when focused on section header")
    func stageFocusedDoesNothingOnSectionHeader() {
        let state = makeState(staged: ["s.swift"])
        state.focus = .section(.staged)
        let focusBefore = state.focus
        state.stageFocused()
        #expect(state.focus == focusBefore)
    }

    @Test("focusedDiffTarget resolves staged file for opening a staged diff")
    func focusedDiffTargetResolvesStagedFile() {
        let state = makeState(staged: ["s.swift"])
        state.focus = .file(section: .staged, path: "s.swift")
        let target = state.focusedDiffTarget()
        #expect(target?.path == "s.swift")
        #expect(target?.isStaged == true)
    }

    @Test("focusedDiffTarget resolves changes file for opening an unstaged diff")
    func focusedDiffTargetResolvesChangesFile() {
        let state = makeState(unstaged: ["u.swift"])
        state.focus = .file(section: .changes, path: "u.swift")
        let target = state.focusedDiffTarget()
        #expect(target?.path == "u.swift")
        #expect(target?.isStaged == false)
    }

    @Test("focusedDiffTarget ignores section headers")
    func focusedDiffTargetIgnoresSectionHeaders() {
        let state = makeState(unstaged: ["u.swift"])
        state.focus = .section(.changes)
        let target = state.focusedDiffTarget()
        #expect(target?.path == nil)
        #expect(target?.isStaged == nil)
    }

    @Test("visibleSections respects visibility flags")
    func visibleSectionsRespectsFlags() {
        let state = makeState(unstaged: ["a.swift"], commits: ["C"])
        state.changesVisible = true
        state.historyVisible = false
        let sections = state.visibleSections
        #expect(!sections.contains(.history))
        #expect(sections.contains(.changes))
    }

    @Test("toggleFocusedExpand expands focused file")
    func toggleFocusedExpandExpandsFile() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        #expect(!state.expandedFilePaths.contains("a.swift"))
        state.toggleFocusedExpand()
        #expect(state.expandedFilePaths.contains("a.swift"))
    }

    @Test("toggleFocusedExpand toggles focused folder")
    func toggleFocusedExpandTogglesFolder() {
        let state = makeState(unstaged: ["Sources/App/a.swift"])
        state.fileListMode = .folders
        state.focus = .folder(section: .changes, path: "Sources/App")

        state.toggleFocusedExpand()
        #expect(state.isFolderExpanded("Sources/App", isStaged: false))

        state.toggleFocusedExpand()
        #expect(!state.isFolderExpanded("Sources/App", isStaged: false))
    }

    @Test("switching to folder mode reconciles nested file focus to visible folder")
    func switchingToFolderModeReconcilesFileFocusToFolder() {
        let state = makeState(unstaged: ["Sources/App/a.swift"])
        state.focus = .file(section: .changes, path: "Sources/App/a.swift")

        state.fileListMode = .folders

        #expect(state.focus == .folder(section: .changes, path: "Sources/App"))
    }

    @Test("toggleFocusedExpand toggles section collapse when section is focused")
    func toggleFocusedExpandTogglesSection() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .section(.changes)
        #expect(!state.changesCollapsed)
        state.toggleFocusedExpand()
        #expect(state.changesCollapsed)
        state.toggleFocusedExpand()
        #expect(!state.changesCollapsed)
    }
}
