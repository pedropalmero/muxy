import AppKit
import os

private let logger = Logger(subsystem: "app.muxy", category: "KeyBindingStore")

@MainActor
@Observable
final class KeyBindingStore {
    static let shared = KeyBindingStore()

    private(set) var bindings: [KeyBinding] = []
    private let persistence: any KeyBindingPersisting

    init(persistence: any KeyBindingPersisting = FileKeyBindingPersistence()) {
        self.persistence = persistence
        load()
    }

    func binding(for action: ShortcutAction) -> KeyBinding {
        bindings.first { $0.action == action }
            ?? KeyBinding.defaults.first { $0.action == action }
            ?? KeyBinding(action: action, combo: KeyCombo(key: "", modifiers: 0))
    }

    func combo(for action: ShortcutAction) -> KeyCombo {
        binding(for: action).combo
    }

    func updateBinding(action: ShortcutAction, combo: KeyCombo) {
        guard let index = bindings.firstIndex(where: { $0.action == action }) else { return }
        if bindings[index].combos.isEmpty {
            bindings[index].combos = [combo]
        } else {
            bindings[index].combos[0] = combo
        }
        save()
    }

    func resetToDefaults() {
        bindings = KeyBinding.defaults
        save()
    }

    func resetBinding(action: ShortcutAction) {
        guard let defaultBinding = KeyBinding.defaults.first(where: { $0.action == action }) else { return }
        updateBinding(action: defaultBinding.action, combo: defaultBinding.combo)
    }

    func isRegisteredShortcut(event: NSEvent, scopes: Set<ShortcutScope>) -> Bool {
        action(for: event, scopes: scopes) != nil
    }

    func action(for event: NSEvent, scopes: Set<ShortcutScope>) -> ShortcutAction? {
        let normalizedKey = KeyCombo.normalized(
            key: event.charactersIgnoringModifiers ?? "",
            keyCode: event.keyCode
        )
        let flags = event.modifierFlags.intersection(KeyCombo.supportedModifierMask).rawValue
        return ShortcutAction.allCases.first { action in
            guard scopes.contains(action.scope) else { return false }
            return binding(for: action).combos.contains { $0.key == normalizedKey && $0.modifiers == flags }
        }
    }

    func action(for combo: KeyCombo, scopes: Set<ShortcutScope>) -> ShortcutAction? {
        ShortcutAction.allCases.first { action in
            guard scopes.contains(action.scope) else { return false }
            return binding(for: action).combos.contains { $0.key == combo.key && $0.modifiers == combo.modifiers }
        }
    }

    func conflictingAction(for combo: KeyCombo, excluding: ShortcutAction) -> ShortcutAction? {
        conflictingAction(for: combo, excluding: Optional(excluding))
    }

    func conflictingAction(for combo: KeyCombo, excluding: ShortcutAction?) -> ShortcutAction? {
        bindings.first { binding in
            guard binding.combos.contains(where: { $0 == combo }) else { return false }
            if let excluding {
                return binding.action != excluding
            }
            return true
        }?.action
    }

    private func load() {
        do {
            bindings = try persistence.loadBindings()
        } catch {
            logger.error("Failed to load key bindings: \(error.localizedDescription)")
            bindings = KeyBinding.defaults
        }
    }

    private func save() {
        do {
            try persistence.saveBindings(bindings)
        } catch {
            logger.error("Failed to save key bindings: \(error.localizedDescription)")
        }
    }
}
