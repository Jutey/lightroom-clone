import SwiftUI

/// Side-effecting binding factories so every edit-panel control gets live, debounced
/// re-rendering without repeating `Binding(get:set:)` boilerplate at each of the ~25+ slider
/// call sites. These bindings only schedule a render/save; undo grouping is a separate
/// concern handled by `EditSliderRow` (for plain sliders) or wired up manually by panels that
/// use a custom drag control (`CurveEditorView`, `ColorWheelView`).
extension EditorViewModel {
    func binding(_ keyPath: WritableKeyPath<EditValues, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit[keyPath: keyPath] },
            set: { newValue in
                self.edit[keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    func boolBinding(_ keyPath: WritableKeyPath<EditValues, Bool>, actionName: String) -> Binding<Bool> {
        Binding(
            get: { self.edit[keyPath: keyPath] },
            set: { newValue in
                let old = self.edit
                self.edit[keyPath: keyPath] = newValue
                self.registerUndo(actionName: actionName, oldEdit: old, oldCrop: self.crop, oldPerspective: self.perspective)
                self.scheduleRenderAndSave()
            }
        )
    }

    func hslBinding(_ band: HSLBandName, _ keyPath: WritableKeyPath<HSLAdjustment, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit.hsl[band, default: HSLAdjustment()][keyPath: keyPath] },
            set: { newValue in
                var adjustment = self.edit.hsl[band, default: HSLAdjustment()]
                adjustment[keyPath: keyPath] = newValue
                self.edit.hsl[band] = adjustment
                self.scheduleRenderAndSave()
            }
        )
    }

    func colorGradingBinding(_ keyPath: WritableKeyPath<ColorGradingValues, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit.colorGrading[keyPath: keyPath] },
            set: { newValue in
                self.edit.colorGrading[keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    func colorGradingWheelBinding(_ keyPath: WritableKeyPath<ColorGradingValues, ColorGradingWheel>) -> Binding<ColorGradingWheel> {
        Binding(
            get: { self.edit.colorGrading[keyPath: keyPath] },
            set: { newValue in
                self.edit.colorGrading[keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    /// Composes `wheelKeyPath` with `\.luminance` so the luminance slider for one of the
    /// three color grading wheels can share the same `binding(_:)`-style call pattern.
    func colorGradingLuminanceBinding(_ wheelKeyPath: WritableKeyPath<ColorGradingValues, ColorGradingWheel>) -> Binding<Double> {
        let composed = wheelKeyPath.appending(path: \ColorGradingWheel.luminance)
        return Binding(
            get: { self.edit.colorGrading[keyPath: composed] },
            set: { newValue in
                self.edit.colorGrading[keyPath: composed] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    /// Tone curve editing is always exactly 5 fixed-x points (see `EditValues.identityCurve`
    /// and `ImageRenderer.applyToneCurve`), so this binding hands the whole point array to
    /// `CurveEditorView` rather than addressing individual fields.
    func toneCurveBinding() -> Binding<[CurvePoint]> {
        Binding(
            get: { self.edit.toneCurve },
            set: { newValue in
                self.edit.toneCurve = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    func lensBinding(_ keyPath: WritableKeyPath<LensValues, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit.lens[keyPath: keyPath] },
            set: { newValue in
                self.edit.lens[keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    func lensBoolBinding(_ keyPath: WritableKeyPath<LensValues, Bool>, actionName: String) -> Binding<Bool> {
        Binding(
            get: { self.edit.lens[keyPath: keyPath] },
            set: { newValue in
                let old = self.edit
                self.edit.lens[keyPath: keyPath] = newValue
                self.registerUndo(actionName: actionName, oldEdit: old, oldCrop: self.crop, oldPerspective: self.perspective)
                self.scheduleRenderAndSave()
            }
        )
    }

    func rawBinding(_ keyPath: WritableKeyPath<RawAdjustments, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit.rawAdjustments[keyPath: keyPath] },
            set: { newValue in
                self.edit.rawAdjustments[keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    func rawBoolBinding(_ keyPath: WritableKeyPath<RawAdjustments, Bool>, actionName: String) -> Binding<Bool> {
        Binding(
            get: { self.edit.rawAdjustments[keyPath: keyPath] },
            set: { newValue in
                let old = self.edit
                self.edit.rawAdjustments[keyPath: keyPath] = newValue
                self.registerUndo(actionName: actionName, oldEdit: old, oldCrop: self.crop, oldPerspective: self.perspective)
                self.scheduleRenderAndSave()
            }
        )
    }

    /// No-ops if no LUT is loaded; `LUTPanelView` only shows this slider when `edit.lut != nil`.
    func lutIntensityBinding() -> Binding<Double> {
        Binding(
            get: { self.edit.lut?.intensity ?? 100 },
            set: { newValue in
                guard self.edit.lut != nil else { return }
                self.edit.lut?.intensity = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    /// No-ops if `maskID` no longer exists (e.g. the mask was deleted while a slider drag was
    /// mid-flight). Undo for drags through this binding is handled by `EditSliderRow`, the
    /// same as every other Double slider — `edit` already covers `localAdjustments`.
    func maskBinding(_ maskID: LocalAdjustmentMask.ID, _ keyPath: WritableKeyPath<LocalAdjustmentMask, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit.localAdjustments.first(where: { $0.id == maskID })?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                guard let index = self.edit.localAdjustments.firstIndex(where: { $0.id == maskID }) else { return }
                self.edit.localAdjustments[index][keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    /// Bool mask fields (e.g. Invert) have no drag gesture to wrap, so this registers undo
    /// immediately on toggle, mirroring `boolBinding(_:actionName:)`.
    func maskBoolBinding(_ maskID: LocalAdjustmentMask.ID, _ keyPath: WritableKeyPath<LocalAdjustmentMask, Bool>, actionName: String) -> Binding<Bool> {
        Binding(
            get: { self.edit.localAdjustments.first(where: { $0.id == maskID })?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard let index = self.edit.localAdjustments.firstIndex(where: { $0.id == maskID }) else { return }
                let old = self.edit
                self.edit.localAdjustments[index][keyPath: keyPath] = newValue
                self.registerUndo(actionName: actionName, oldEdit: old, oldCrop: self.crop, oldPerspective: self.perspective)
                self.scheduleRenderAndSave()
            }
        )
    }

    /// No-ops if `spotID` no longer exists (e.g. the spot was deleted while a slider drag was
    /// mid-flight). Mirrors `maskBinding(_:_:)`.
    func spotBinding(_ spotID: SpotRemoval.ID, _ keyPath: WritableKeyPath<SpotRemoval, Double>) -> Binding<Double> {
        Binding(
            get: { self.edit.spotRemovals.first(where: { $0.id == spotID })?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                guard let index = self.edit.spotRemovals.firstIndex(where: { $0.id == spotID }) else { return }
                self.edit.spotRemovals[index][keyPath: keyPath] = newValue
                self.scheduleRenderAndSave()
            }
        )
    }

    /// Bool spot fields (e.g. enabled toggle) have no drag gesture to wrap, so this registers
    /// undo immediately, mirroring `maskBoolBinding(_:_:actionName:)`.
    func spotBoolBinding(_ spotID: SpotRemoval.ID, _ keyPath: WritableKeyPath<SpotRemoval, Bool>, actionName: String) -> Binding<Bool> {
        Binding(
            get: { self.edit.spotRemovals.first(where: { $0.id == spotID })?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard let index = self.edit.spotRemovals.firstIndex(where: { $0.id == spotID }) else { return }
                let old = self.edit
                self.edit.spotRemovals[index][keyPath: keyPath] = newValue
                self.registerUndo(actionName: actionName, oldEdit: old, oldCrop: self.crop, oldPerspective: self.perspective)
                self.scheduleRenderAndSave()
            }
        )
    }
}
