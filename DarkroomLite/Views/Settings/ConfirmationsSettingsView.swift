import SwiftUI

/// Toggles for the confirmation alerts shown elsewhere in the app (delete, batch apply,
/// discarding unconfirmed geometry changes).
struct ConfirmationsSettingsView: View {
    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Toggle("Confirm Before Moving Photos to Trash", isOn: $settings.confirmBeforeDelete)
            Toggle("Confirm Before Batch-Applying Edits", isOn: $settings.confirmBeforeBatchApply)
            Toggle("Warn Before Discarding Unsaved Crop/Perspective Changes", isOn: $settings.warnBeforeDiscardingGeometryChanges)
        }
        .padding(20)
    }
}
