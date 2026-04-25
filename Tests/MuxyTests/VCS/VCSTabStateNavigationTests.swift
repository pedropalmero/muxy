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
}
