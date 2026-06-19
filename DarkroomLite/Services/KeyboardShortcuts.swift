import Foundation
import AppKit
import Observation

/// Every action in the app that can be triggered from the keyboard. New actions should
/// be added here and given a sensible `defaultCombo` — everything else (persistence,
/// the Settings > Keyboard Shortcuts editor, and conflict-free matching) follows for free.
enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case nextPhoto, previousPhoto
    case togglePick, reject, clearFlag
    case rating0, rating1, rating2, rating3, rating4, rating5
    case deletePhoto, exitTool
    case viewGrid, viewLoupe, viewCompare, viewBeforeAfter
    case cropTool, perspectiveTool
    case undo, redo
    case copyEdits, pasteEdits, resetEdits
    case exportSelected
    case colorLabelNone, colorLabelRed, colorLabelYellow, colorLabelGreen, colorLabelBlue, colorLabelPurple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nextPhoto: return "Next Photo"
        case .previousPhoto: return "Previous Photo"
        case .togglePick: return "Toggle Pick / Favorite"
        case .reject: return "Reject"
        case .clearFlag: return "Clear Flag"
        case .rating0: return "Clear Rating"
        case .rating1: return "Rating: 1 Star"
        case .rating2: return "Rating: 2 Stars"
        case .rating3: return "Rating: 3 Stars"
        case .rating4: return "Rating: 4 Stars"
        case .rating5: return "Rating: 5 Stars"
        case .deletePhoto: return "Move to Trash"
        case .exitTool: return "Exit Active Tool"
        case .viewGrid: return "Grid View"
        case .viewLoupe: return "Loupe View"
        case .viewCompare: return "Compare View"
        case .viewBeforeAfter: return "Before / After"
        case .cropTool: return "Crop Tool"
        case .perspectiveTool: return "Perspective Tool"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .copyEdits: return "Copy Edits"
        case .pasteEdits: return "Paste Edits"
        case .resetEdits: return "Reset All Edits"
        case .exportSelected: return "Export Selected"
        case .colorLabelNone: return "Color Label: None"
        case .colorLabelRed: return "Color Label: Red"
        case .colorLabelYellow: return "Color Label: Yellow"
        case .colorLabelGreen: return "Color Label: Green"
        case .colorLabelBlue: return "Color Label: Blue"
        case .colorLabelPurple: return "Color Label: Purple"
        }
    }

    var defaultCombo: KeyCombo {
        switch self {
        case .nextPhoto: return KeyCombo(key: "right")
        case .previousPhoto: return KeyCombo(key: "left")
        case .togglePick: return KeyCombo(key: "space")
        case .reject: return KeyCombo(key: "x")
        case .clearFlag: return KeyCombo(key: "u")
        case .rating0: return KeyCombo(key: "0")
        case .rating1: return KeyCombo(key: "1")
        case .rating2: return KeyCombo(key: "2")
        case .rating3: return KeyCombo(key: "3")
        case .rating4: return KeyCombo(key: "4")
        case .rating5: return KeyCombo(key: "5")
        case .deletePhoto: return KeyCombo(key: "delete")
        case .exitTool: return KeyCombo(key: "escape")
        case .viewGrid: return KeyCombo(key: "g")
        case .viewLoupe: return KeyCombo(key: "e")
        case .viewCompare: return KeyCombo(key: "c")
        case .viewBeforeAfter: return KeyCombo(key: "\\")
        case .cropTool: return KeyCombo(key: "r")
        case .perspectiveTool: return KeyCombo(key: "p", shift: true)
        case .undo: return KeyCombo(key: "z", command: true)
        case .redo: return KeyCombo(key: "z", shift: true, command: true)
        case .copyEdits: return KeyCombo(key: "c", command: true, option: true)
        case .pasteEdits: return KeyCombo(key: "v", command: true, option: true)
        case .resetEdits: return KeyCombo(key: "r", shift: true, command: true)
        case .exportSelected: return KeyCombo(key: "e", command: true)
        case .colorLabelNone: return KeyCombo(key: "6")
        case .colorLabelRed: return KeyCombo(key: "7")
        case .colorLabelYellow: return KeyCombo(key: "8")
        case .colorLabelGreen: return KeyCombo(key: "9")
        case .colorLabelBlue: return KeyCombo(key: "")
        case .colorLabelPurple: return KeyCombo(key: "")
        }
    }
}

/// A single key plus modifier flags. `key` is either one printable lowercase character
/// or one of the symbolic names: left, right, up, down, space, delete, escape, return, tab.
struct KeyCombo: Codable, Equatable, Hashable {
    var key: String
    var shift: Bool = false
    var command: Bool = false
    var option: Bool = false
    var control: Bool = false

    var isEmpty: Bool { key.isEmpty }

    var displayString: String {
        guard !key.isEmpty else { return "—" }
        var parts = ""
        if control { parts += "⌃" }
        if option { parts += "⌥" }
        if shift { parts += "⇧" }
        if command { parts += "⌘" }
        parts += KeyCombo.glyph(for: key)
        return parts
    }

    static func glyph(for key: String) -> String {
        switch key {
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "space": return "Space"
        case "delete": return "⌫"
        case "escape": return "⎋"
        case "return": return "⏎"
        case "tab": return "⇥"
        case "\\": return "\\"
        default: return key.uppercased()
        }
    }

    static func from(event: NSEvent) -> KeyCombo? {
        let flags = event.modifierFlags
        let key: String
        switch event.keyCode {
        case 123: key = "left"
        case 124: key = "right"
        case 125: key = "down"
        case 126: key = "up"
        case 51, 117: key = "delete"
        case 53: key = "escape"
        case 49: key = "space"
        case 36: key = "return"
        case 48: key = "tab"
        default:
            guard let characters = event.charactersIgnoringModifiers?.lowercased(), !characters.isEmpty else {
                return nil
            }
            key = characters
        }
        return KeyCombo(
            key: key,
            shift: flags.contains(.shift),
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
    }
}

/// Persists the (possibly user-customized) keyboard shortcut map and matches incoming
/// `NSEvent`s against it. Backed by `UserDefaults` so it survives relaunches.
@Observable
final class KeyboardShortcutsStore {
    static let shared = KeyboardShortcutsStore()

    private(set) var combos: [ShortcutAction: KeyCombo]
    private let defaultsKey = "DarkroomLite.KeyboardShortcuts"

    private init() {
        var initial: [ShortcutAction: KeyCombo] = [:]
        for action in ShortcutAction.allCases {
            initial[action] = action.defaultCombo
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: KeyCombo].self, from: data) {
            for (rawValue, combo) in saved {
                if let action = ShortcutAction(rawValue: rawValue) {
                    initial[action] = combo
                }
            }
        }
        combos = initial
    }

    func combo(for action: ShortcutAction) -> KeyCombo {
        combos[action] ?? action.defaultCombo
    }

    func setCombo(_ combo: KeyCombo, for action: ShortcutAction) {
        combos[action] = combo
        persist()
    }

    func resetToDefaults() {
        for action in ShortcutAction.allCases {
            combos[action] = action.defaultCombo
        }
        persist()
    }

    func resetAction(_ action: ShortcutAction) {
        combos[action] = action.defaultCombo
        persist()
    }

    func action(for event: NSEvent) -> ShortcutAction? {
        guard let combo = KeyCombo.from(event: event) else { return nil }
        return combos.first { $0.value == combo && !combo.isEmpty }?.key
    }

    private func persist() {
        let serializable = Dictionary(uniqueKeysWithValues: combos.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(serializable) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
