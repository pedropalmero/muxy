import Foundation
import Testing

@testable import Muxy

@Suite("KeyBindingStore vcsPanel scope")
@MainActor
struct KeyBindingStoreVCSScopeTests {
    @Test("vcsNextRow default combo is vim 'j' key")
    func vcsNextRowDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsNextRow)
        #expect(combo.key == "j")
        #expect(combo.modifiers == 0)
    }

    @Test("vcsPrevRow default combo is vim 'k' key")
    func vcsPrevRowDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsPrevRow)
        #expect(combo.key == "k")
        #expect(combo.modifiers == 0)
    }

    @Test("vcsStageSelected default combos include 's' and cmd+shift+s")
    func vcsStageSelectedCombos() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let binding = store.binding(for: .vcsStageSelected)
        let keys = binding.combos.map(\.key)
        #expect(keys.contains("s"))
        let cmdShiftS = binding.combos.first {
            $0.key == "s" && $0.nsModifierFlags.contains(.command) && $0.nsModifierFlags.contains(.shift)
        }
        #expect(cmdShiftS != nil)
    }

    @Test("action(for combo:scopes:) finds vcsNextRow with bare j in vcsPanel scope")
    func actionForComboFindsVCSNextRow() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let jCombo = KeyCombo(key: "j")
        let result = store.action(for: jCombo, scopes: [.vcsPanel])
        #expect(result == .vcsNextRow)
    }

    @Test("action(for combo:scopes:) returns nil for vcsPanel action when mainWindow scope only")
    func actionForComboReturnsNilForWrongScope() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let jCombo = KeyCombo(key: "j")
        let result = store.action(for: jCombo, scopes: [.mainWindow])
        #expect(result == nil)
    }

    @Test("action(for combo:scopes:) finds secondary combo (down arrow) for vcsNextRow")
    func actionForComboFindsSecondaryCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let downCombo = KeyCombo(key: KeyCombo.downArrowKey)
        let result = store.action(for: downCombo, scopes: [.vcsPanel])
        #expect(result == .vcsNextRow)
    }

    @Test("all VCS actions have vcsPanel scope")
    func vcsActionsHaveVCSPanelScope() {
        let vcsActions: [ShortcutAction] = [
            .vcsNextRow, .vcsPrevRow, .vcsNextSection, .vcsPrevSection,
            .vcsActivateRow, .vcsToggleExpand, .vcsStageSelected, .vcsUnstageSelected,
            .vcsDiscardSelected, .vcsOpenInEditor, .vcsOpenDiffInTab, .vcsFocusCommitMessage,
            .vcsRefresh, .vcsPush, .vcsPull, .vcsBranchPicker, .vcsNewBranch, .vcsCreatePR,
            .vcsNextHunk, .vcsPrevHunk, .vcsCopyLineRef,
        ]
        for action in vcsActions {
            #expect(action.scope == .vcsPanel, "Expected .vcsPanel scope for \(action)")
        }
    }

    @Test("VCS actions appear in Source Control category")
    func vcsActionsInSourceControlCategory() {
        let vcsActions: [ShortcutAction] = [.vcsNextRow, .vcsStageSelected, .vcsRefresh]
        for action in vcsActions {
            #expect(action.category == "Source Control")
        }
    }
}

private final class InMemoryKeyBindingPersistence: KeyBindingPersisting {
    func loadBindings() throws -> [KeyBinding] { [] }
    func saveBindings(_ bindings: [KeyBinding]) throws {}
}
