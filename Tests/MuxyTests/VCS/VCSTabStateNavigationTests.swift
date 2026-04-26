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

    @Test("selectNextRow from section header enters first row when expanded")
    func selectNextRowFromSectionHeader() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.focus = .section(.changes)
        state.selectNextRow()
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
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

    @Test("stageOrUnstageFocusedFile stages a changes file and advances focus to next")
    func stageOrUnstageStagesChangesFileAdvancesFocus() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        let acted = state.stageOrUnstageFocusedFile()
        #expect(acted)
        #expect(state.focus == .file(section: .changes, path: "b.swift"))
    }

    @Test("stageOrUnstageFocusedFile moves focus to previous when staging last file")
    func stageOrUnstageLastFileMovesFocusToPrev() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.focus = .file(section: .changes, path: "b.swift")
        let acted = state.stageOrUnstageFocusedFile()
        #expect(acted)
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("stageOrUnstageFocusedFile moves focus to adjacent section when only file is staged")
    func stageOrUnstageOnlyFileMovesFocusToAdjacentSection() {
        let state = makeState(unstaged: ["a.swift"], commits: ["Initial"])
        state.focus = .file(section: .changes, path: "a.swift")
        let acted = state.stageOrUnstageFocusedFile()
        #expect(acted)
        #expect(state.focus == .section(.history))
    }

    @Test("stageOrUnstageFocusedFile moves focus to next section when unstaging only staged file")
    func stageOrUnstageOnlyStagedFileMovesFocusToChanges() {
        let state = makeState(staged: ["s.swift"], unstaged: ["u.swift"])
        state.focus = .file(section: .staged, path: "s.swift")
        let acted = state.stageOrUnstageFocusedFile()
        #expect(acted)
        #expect(state.focus == .section(.changes))
    }

    @Test("stageOrUnstageFocusedFile unstages a staged file and advances focus")
    func stageOrUnstageUnstagesStagedFileAdvancesFocus() {
        let state = makeState(staged: ["s.swift", "t.swift"])
        state.focus = .file(section: .staged, path: "s.swift")
        let acted = state.stageOrUnstageFocusedFile()
        #expect(acted)
        #expect(state.focus == .file(section: .staged, path: "t.swift"))
    }

    @Test("stageOrUnstageFocusedFile returns false for section focus")
    func stageOrUnstageReturnsFalseForSection() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .section(.changes)
        let acted = state.stageOrUnstageFocusedFile()
        #expect(!acted)
        #expect(state.focus == .section(.changes))
    }

    @Test("stageOrUnstageFocusedFile returns false for commit focus")
    func stageOrUnstageReturnsFalseForCommit() {
        let state = makeState(commits: ["Initial"])
        state.focus = .commit(hash: "hash0")
        let acted = state.stageOrUnstageFocusedFile()
        #expect(!acted)
        #expect(state.focus == .commit(hash: "hash0"))
    }

    @Test("collapseOrParent collapses an expanded section")
    func collapseOrParentCollapsesSection() {
        let state = makeState(unstaged: ["a.swift"])
        state.changesCollapsed = false
        state.focus = .section(.changes)
        state.collapseOrParent()
        #expect(state.changesCollapsed)
    }

    @Test("collapseOrParent is no-op on already collapsed section")
    func collapseOrParentNoOpOnCollapsedSection() {
        let state = makeState(unstaged: ["a.swift"])
        state.changesCollapsed = true
        state.focus = .section(.changes)
        state.collapseOrParent()
        #expect(state.changesCollapsed)
    }

    @Test("collapseOrParent collapses expanded file diff")
    func collapseOrParentCollapsesFileDiff() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.expandedFilePaths.insert("a.swift")
        state.collapseOrParent()
        #expect(!state.expandedFilePaths.contains("a.swift"))
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("collapseOrParent moves focus to section header when file diff is collapsed")
    func collapseOrParentMovesToSectionHeader() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.collapseOrParent()
        #expect(state.focus == .section(.changes))
    }

    @Test("collapseOrParent moves commit focus to history section")
    func collapseOrParentMovesCommitToHistory() {
        let state = makeState(commits: ["Initial"])
        state.focus = .commit(hash: "hash0")
        state.collapseOrParent()
        #expect(state.focus == .section(.history))
    }

    @Test("collapseOrParent moves pullRequest focus to pullRequests section")
    func collapseOrParentMovesPRToPRSection() {
        let state = makeState()
        state.pullRequestsVisible = true
        state.focus = .pullRequest(number: 42)
        state.collapseOrParent()
        #expect(state.focus == .section(.pullRequests))
    }

    @Test("expandOrFirstChild expands a collapsed section")
    func expandOrFirstChildExpandsSection() {
        let state = makeState(unstaged: ["a.swift"])
        state.changesCollapsed = true
        state.focus = .section(.changes)
        state.expandOrFirstChild()
        #expect(!state.changesCollapsed)
    }

    @Test("expandOrFirstChild moves into first row of already expanded section")
    func expandOrFirstChildMovesToFirstRow() {
        let state = makeState(unstaged: ["a.swift", "b.swift"])
        state.changesCollapsed = false
        state.focus = .section(.changes)
        state.expandOrFirstChild()
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("expandOrFirstChild expands collapsed file diff")
    func expandOrFirstChildExpandsFileDiff() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        #expect(!state.expandedFilePaths.contains("a.swift"))
        state.expandOrFirstChild()
        #expect(state.expandedFilePaths.contains("a.swift"))
    }

    @Test("expandOrFirstChild is no-op on already expanded file diff")
    func expandOrFirstChildNoOpOnExpandedFileDiff() {
        let state = makeState(unstaged: ["a.swift"])
        state.focus = .file(section: .changes, path: "a.swift")
        state.expandedFilePaths.insert("a.swift")
        state.expandOrFirstChild()
        #expect(state.expandedFilePaths.contains("a.swift"))
        #expect(state.focus == .file(section: .changes, path: "a.swift"))
    }

    @Test("expandOrFirstChild is no-op on commit focus")
    func expandOrFirstChildNoOpOnCommit() {
        let state = makeState(commits: ["Initial"])
        state.focus = .commit(hash: "hash0")
        state.expandOrFirstChild()
        #expect(state.focus == .commit(hash: "hash0"))
    }
}
