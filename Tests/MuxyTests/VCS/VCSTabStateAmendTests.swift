import Foundation
import Testing

@testable import Muxy

@Suite("VCSTabState Amend")
@MainActor
struct VCSTabStateAmendTests {
    private func makeState(
        staged: [String] = [],
        message: String = ""
    ) -> VCSTabState {
        let state = VCSTabState(projectPath: "/tmp/muxy-amend-test-\(UUID().uuidString)")
        state.files = staged.map {
            GitStatusFile(path: $0, oldPath: nil, xStatus: "M", yStatus: " ", additions: nil, deletions: nil, isBinary: false)
        }
        state.commitMessage = message
        return state
    }

    @Test("commit is rejected with no staged changes and amendMode off")
    func commitRejectedWithoutStagedChanges() {
        let state = makeState(message: "fix: something")
        state.commit()
        #expect(state.isCommitting == false)
        #expect(state.statusIsError == true)
        #expect(state.statusMessage == "No staged changes to commit.")
    }

    @Test("commit is rejected with empty message regardless of amendMode")
    func commitRejectedWithEmptyMessage() {
        let state = makeState(message: "")
        state.amendMode = true
        state.commit()
        #expect(state.isCommitting == false)
        #expect(state.statusIsError == true)
        #expect(state.statusMessage == "Enter a commit message.")
    }

    @Test("commit proceeds past guards when amendMode is on with no staged changes")
    func commitProceedsInAmendModeWithNoStagedChanges() {
        let state = makeState(message: "fix: amend me")
        state.amendMode = true
        state.commit()
        #expect(state.isCommitting == true)
    }

    @Test("cancelAmendMode clears amendMode flag")
    func cancelAmendModeClearsFlag() {
        let state = makeState(message: "fix: in progress")
        state.amendMode = true
        state.cancelAmendMode()
        #expect(state.amendMode == false)
    }

@Test("amendKeepingMessage sets isCommitting when not already committing")
    func amendKeepingMessageSetsCommitting() {
        let state = makeState()
        state.amendKeepingMessage()
        #expect(state.isCommitting == true)
    }

    @Test("amendKeepingMessage is no-op when already committing")
    func amendKeepingMessageIsNoOpIfCommitting() {
        let state = makeState()
        state.isCommitting = true
        state.amendKeepingMessage()
        #expect(state.isCommitting == true)
    }
}
