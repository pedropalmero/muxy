import AppKit
import Testing

@testable import Muxy

@Suite("VCS commit message editor commands")
struct VCSCommitMessageEditorCommandMapperTests {
    @Test("insertTab maps to next panel target")
    func insertTabMapsToNextPanelTarget() {
        let command = VCSCommitMessageEditorCommandMapper.command(for: #selector(NSResponder.insertTab(_:)))
        #expect(command == .focusNext)
    }

    @Test("insertBacktab maps to previous panel target")
    func insertBacktabMapsToPreviousPanelTarget() {
        let command = VCSCommitMessageEditorCommandMapper.command(for: #selector(NSResponder.insertBacktab(_:)))
        #expect(command == .focusPrevious)
    }

    @Test("cancelOperation maps to escape")
    func cancelOperationMapsToEscape() {
        let command = VCSCommitMessageEditorCommandMapper.command(for: #selector(NSResponder.cancelOperation(_:)))
        #expect(command == .escape)
    }
}
