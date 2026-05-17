import AppKit
import Foundation
import Testing

@testable import Muxy

@Suite("KeyBindingStore vcsPanel scope")
@MainActor
struct KeyBindingStoreVCSScopeTests {
    @Test("vcsNextRow default combo is down arrow")
    func vcsNextRowDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsNextRow)
        #expect(combo.key == KeyCombo.downArrowKey)
        #expect(combo.modifiers == 0)
    }

    @Test("vcsPrevRow default combo is up arrow")
    func vcsPrevRowDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsPrevRow)
        #expect(combo.key == KeyCombo.upArrowKey)
        #expect(combo.modifiers == 0)
    }

    @Test("vcsNextSection default combo is tab")
    func vcsNextSectionDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsNextSection)
        #expect(combo == KeyCombo(key: KeyCombo.tabKey))
    }

    @Test("vcsPrevSection default combo is shift+tab")
    func vcsPrevSectionDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsPrevSection)
        #expect(combo == KeyCombo(key: KeyCombo.tabKey, shift: true))
    }

    @Test("vcsActivateRow default combo is return")
    func vcsActivateRowDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsActivateRow)
        #expect(combo == KeyCombo(key: KeyCombo.returnKey))
    }

    @Test("vcsToggleExpand default combo is space")
    func vcsToggleExpandDefaultCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsToggleExpand)
        #expect(combo == KeyCombo(key: " "))
    }

    @Test("vcsStageSelected default combo is bare s")
    func vcsStageSelectedCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsStageSelected)
        #expect(combo == KeyCombo(key: "s"))
    }

    @Test("vcsUnstageSelected default combo is bare u")
    func vcsUnstageSelectedCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsUnstageSelected)
        #expect(combo == KeyCombo(key: "u"))
    }

    @Test("vcsDiscardSelected default combo is bare d")
    func vcsDiscardSelectedCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsDiscardSelected)
        #expect(combo == KeyCombo(key: "d"))
    }

    @Test("vcsOpenDiff default combo is bare o")
    func vcsOpenDiffCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsOpenDiff)
        #expect(combo == KeyCombo(key: "o"))
    }

    @Test("vcsStageAll default combo is shift+s")
    func vcsStageAllCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsStageAll)
        #expect(combo == KeyCombo(key: "s", shift: true))
    }

    @Test("vcsUnstageAll default combo is shift+u")
    func vcsUnstageAllCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsUnstageAll)
        #expect(combo == KeyCombo(key: "u", shift: true))
    }

    @Test("vcsDiscardAll default combo is shift+d")
    func vcsDiscardAllCombo() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let combo = store.combo(for: .vcsDiscardAll)
        #expect(combo == KeyCombo(key: "d", shift: true))
    }

    @Test("action(for combo:scopes:) finds vcsNextRow with down arrow in vcsPanel scope")
    func actionForComboFindsVCSNextRow() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let downCombo = KeyCombo(key: KeyCombo.downArrowKey)
        let result = store.action(for: downCombo, scopes: [.vcsPanel])
        #expect(result == .vcsNextRow)
    }

    @Test("action(for combo:scopes:) finds vcsNextSection with bare tab in vcsPanel scope")
    func actionForComboFindsVCSNextSection() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let tabCombo = KeyCombo(key: KeyCombo.tabKey)
        let result = store.action(for: tabCombo, scopes: [.vcsPanel])
        #expect(result == .vcsNextSection)
    }

    @Test("action(for combo:scopes:) returns nil for vcsPanel action when mainWindow scope only")
    func actionForComboReturnsNilForWrongScope() {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let tabCombo = KeyCombo(key: KeyCombo.tabKey)
        let result = store.action(for: tabCombo, scopes: [.mainWindow])
        #expect(result == nil)
    }

    @Test("vcs single-letter shortcuts resolve by physical key code")
    func singleLetterShortcutsResolveByPhysicalKeyCode() throws {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let event = try keyEvent(
            characters: "ы",
            charactersIgnoringModifiers: "ы",
            keyCode: 1,
            modifiers: []
        )

        #expect(store.action(for: event, scopes: [.vcsPanel]) == .vcsStageSelected)
    }

    @Test("vcs single-letter shortcuts stay out of main window scope")
    func singleLetterShortcutsStayOutOfMainWindowScope() throws {
        let store = KeyBindingStore(persistence: InMemoryKeyBindingPersistence())
        let event = try keyEvent(
            characters: "s",
            charactersIgnoringModifiers: "s",
            keyCode: 1,
            modifiers: []
        )

        #expect(store.action(for: event, scopes: [.mainWindow]) == nil)
    }

    @Test("all VCS actions have vcsPanel scope")
    func vcsActionsHaveVCSPanelScope() {
        let vcsActions: [ShortcutAction] = [
            .vcsNextRow, .vcsPrevRow, .vcsNextSection, .vcsPrevSection,
            .vcsActivateRow, .vcsToggleExpand,
            .vcsStageSelected, .vcsUnstageSelected, .vcsDiscardSelected,
            .vcsOpenDiff, .vcsStageAll, .vcsUnstageAll, .vcsDiscardAll,
        ]
        for action in vcsActions {
            #expect(action.scope == .vcsPanel, "Expected .vcsPanel scope for \(action)")
        }
    }

    @Test("VCS actions appear in Source Control category")
    func vcsActionsInSourceControlCategory() {
        let vcsActions: [ShortcutAction] = [.vcsNextRow, .vcsStageSelected, .vcsActivateRow]
        for action in vcsActions {
            #expect(action.category == "Source Control")
        }
    }

    private func keyEvent(
        characters: String,
        charactersIgnoringModifiers: String,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode
        ) else {
            throw EventCreationError()
        }
        return event
    }
}

private final class InMemoryKeyBindingPersistence: KeyBindingPersisting {
    func loadBindings() throws -> [KeyBinding] { [] }
    func saveBindings(_ bindings: [KeyBinding]) throws {}
}

private struct EventCreationError: Error {}
