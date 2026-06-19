import SwiftUI

/// Default behavior for the Crop and Perspective tools: whether changes auto-apply on
/// exit or require an explicit Confirm, and the default guide overlay shown in Crop.
struct CropPerspectiveSettingsView: View {
    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Section("Crop") {
                Picker("When Exiting Crop", selection: $settings.cropAutoApplyBehavior) {
                    ForEach(GeometryConfirmBehavior.allCases) { behavior in
                        Text(behavior.label).tag(behavior)
                    }
                }

                Picker("Default Guide Overlay", selection: $settings.defaultCropGuideOverlay) {
                    ForEach(CropGuideOverlay.allCases) { overlay in
                        Text(overlay.label).tag(overlay)
                    }
                }
            }

            Section("Perspective") {
                Picker("When Exiting Perspective", selection: $settings.perspectiveAutoApplyBehavior) {
                    ForEach(GeometryConfirmBehavior.allCases) { behavior in
                        Text(behavior.label).tag(behavior)
                    }
                }
            }
        }
        .padding(20)
    }
}
