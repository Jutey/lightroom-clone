import SwiftUI

/// Lists every `ShortcutAction` with its current `KeyCombo` and lets the user re-record
/// or reset each one individually, plus a global "Reset All" for the whole map.
struct KeyboardShortcutsSettingsView: View {
    @State private var recordingAction: ShortcutAction?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(ShortcutAction.allCases) { action in
                    row(for: action)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                if recordingAction != nil {
                    Text("Press a key combination, or Esc to cancel…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset All to Defaults") {
                    KeyboardShortcutsStore.shared.resetToDefaults()
                }
            }
            .padding(20)
        }
        .background(
            ShortcutRecorderView(
                isRecording: isRecordingBinding,
                onCapture: { combo in
                    if let action = recordingAction {
                        KeyboardShortcutsStore.shared.setCombo(combo, for: action)
                    }
                    recordingAction = nil
                },
                onCancel: { recordingAction = nil }
            )
        )
    }

    private func row(for action: ShortcutAction) -> some View {
        HStack {
            Text(action.displayName)
            Spacer()
            Text(KeyboardShortcutsStore.shared.combo(for: action).displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Button(recordingAction == action ? "Press a key…" : "Record") {
                recordingAction = action
            }
            .buttonStyle(.bordered)
            .frame(width: 110)
            Button {
                KeyboardShortcutsStore.shared.resetAction(action)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .help("Reset to default")
        }
    }

    private var isRecordingBinding: Binding<Bool> {
        Binding(get: { recordingAction != nil }, set: { if !$0 { recordingAction = nil } })
    }
}
