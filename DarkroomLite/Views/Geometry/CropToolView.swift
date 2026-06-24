import SwiftUI

/// Interactive crop overlay drawn on top of the loupe preview, Snipping-Tool style: drag
/// anywhere on the dimmed area to draw a brand new crop box, or drag the existing box's
/// handles/interior to adjust it. Either way, releasing the mouse finalizes the crop
/// immediately — there's no separate Confirm step. Every drag pushes one undo step, so
/// Cmd+Z steps back through crop changes the same way it does for every other edit.
/// The crop rectangle is normalized (0...1) against the *displayed* preview image, which
/// already has rotate/flip/straighten baked in (see `ImageRenderer.applyGeometry`'s ordering).
struct CropToolView: View {
    @Environment(AppController.self) private var app

    private enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    @State private var dragStartViewRect: CGRect?
    @State private var dragStartCropValues: CropValues?
    @State private var newSelectionStart: CGPoint?
    @State private var straightenStartCrop: CropValues?

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(containerSize: geo.size, imageSize: app.editor.previewImage?.size ?? geo.size)
            let cropRect = viewCropRect(in: imageRect)

            ZStack(alignment: .topLeading) {
                dimmingOverlay(imageRect: imageRect, cropRect: cropRect)

                GridGuide(kind: SettingsStore.shared.defaultCropGuideOverlay)
                    .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .contentShape(Rectangle())
                    .gesture(panGesture(imageRect: imageRect, cropRect: cropRect))

                ForEach(Handle.allCases, id: \.self) { handle in
                    handleView(handle, cropRect: cropRect, imageRect: imageRect)
                }

                VStack {
                    Spacer()
                    controlBar
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(AspectRatioOption.allCases) { option in
                        Button(option.label) { applyAspectRatio(option) }
                    }
                } label: {
                    Label(app.editor.crop.aspectRatio.label, systemImage: "aspectratio")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button { rotateQuarterTurn(1) } label: {
                    Image(systemName: "rotate.right")
                }
                Button { rotateQuarterTurn(-1) } label: {
                    Image(systemName: "rotate.left")
                }
                Button { toggleFlip(horizontal: true) } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                Button { toggleFlip(horizontal: false) } label: {
                    Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                }
                Button("Auto") { app.editor.autoStraighten() }
                    .help("Auto Straighten")

                HStack(spacing: 4) {
                    Text("Straighten")
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { app.editor.crop.straightenAngle },
                            set: { app.editor.crop.straightenAngle = $0; app.editor.scheduleRenderAndSave() }
                        ),
                        in: -45...45,
                        onEditingChanged: { editing in
                            if editing {
                                straightenStartCrop = app.editor.crop
                            } else if let old = straightenStartCrop {
                                registerCropUndo(actionName: "Straighten", old: old)
                                straightenStartCrop = nil
                            }
                        }
                    )
                    .frame(width: 140)
                    Text("\(Int(app.editor.crop.straightenAngle))°")
                        .font(.caption.monospacedDigit())
                        .frame(width: 32)
                }

                Button("Reset") { applyCrop(.identity, actionName: "Reset Crop") }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)

            Text("Drag to draw a new crop, or adjust the handles. Releasing finalizes it — ⌘Z to undo.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5), in: Capsule())

            Button("Done") {
                app.requestActiveTool(.none)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 12)
        }
    }

    private func applyAspectRatio(_ option: AspectRatioOption) {
        var crop = app.editor.crop
        crop.aspectRatio = option
        if let ratio = option.fixedRatio {
            let center = CGPoint(x: crop.normalizedX + crop.normalizedWidth / 2, y: crop.normalizedY + crop.normalizedHeight / 2)
            var width = crop.normalizedWidth
            var height = width / ratio
            if height > 1 {
                height = 1
                width = height * ratio
            }
            crop.normalizedWidth = min(1, width)
            crop.normalizedHeight = min(1, height)
            crop.normalizedX = max(0, min(1 - crop.normalizedWidth, center.x - crop.normalizedWidth / 2))
            crop.normalizedY = max(0, min(1 - crop.normalizedHeight, center.y - crop.normalizedHeight / 2))
        }
        applyCrop(crop, actionName: "Aspect Ratio")
    }

    private func rotateQuarterTurn(_ delta: Int) {
        var crop = app.editor.crop
        crop.rotationQuarterTurns = ((crop.rotationQuarterTurns + delta) % 4 + 4) % 4
        applyCrop(crop, actionName: "Rotate Crop")
    }

    private func toggleFlip(horizontal: Bool) {
        var crop = app.editor.crop
        if horizontal {
            crop.flipHorizontal.toggle()
        } else {
            crop.flipVertical.toggle()
        }
        applyCrop(crop, actionName: horizontal ? "Flip Horizontal" : "Flip Vertical")
    }

    // MARK: - Crop mutation + undo helpers

    /// Applies an immediate, discrete crop change (reset, aspect ratio, rotate, flip) as a
    /// single undoable step.
    private func applyCrop(_ newCrop: CropValues, actionName: String) {
        let old = app.editor.crop
        guard old != newCrop else { return }
        app.editor.crop = newCrop
        registerCropUndo(actionName: actionName, old: old)
    }

    private func registerCropUndo(actionName: String, old: CropValues) {
        guard old != app.editor.crop else { return }
        app.editor.registerUndo(actionName: actionName, oldEdit: app.editor.edit, oldCrop: old, oldPerspective: app.editor.perspective)
        app.editor.confirmCrop()
        app.editor.scheduleRenderAndSave()
    }

    /// Called at the end of any drag (drawing a new box, panning, or resizing via a handle):
    /// pushes one undo step covering the whole drag, then finalizes the crop immediately —
    /// this is what makes the tool "auto-finalize on release" rather than requiring a
    /// separate Confirm action.
    private func finalizeDrag() {
        if let old = dragStartCropValues {
            registerCropUndo(actionName: "Crop", old: old)
        }
        dragStartCropValues = nil
        dragStartViewRect = nil
    }

    // MARK: - Handles

    @ViewBuilder
    private func handleView(_ handle: Handle, cropRect: CGRect, imageRect: CGRect) -> some View {
        let point = position(for: handle, in: cropRect)
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .shadow(radius: 1)
            .position(point)
            .gesture(resizeGesture(handle, imageRect: imageRect, cropRect: cropRect))
    }

    private func position(for handle: Handle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    // MARK: - Gestures

    /// Drawing a brand new crop box by dragging on the dimmed area, Snipping-Tool style.
    /// Replaces whatever crop box currently exists with the freshly dragged rectangle, live,
    /// and finalizes it the moment the mouse is released.
    private func newSelectionGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if newSelectionStart == nil {
                    newSelectionStart = value.startLocation
                    dragStartCropValues = app.editor.crop
                }
                guard let start = newSelectionStart else { return }
                let rect = clampedSize(rect(from: start, to: value.location), in: imageRect)
                app.editor.crop = cropValues(fromViewRect: rect, imageRect: imageRect)
            }
            .onEnded { _ in
                newSelectionStart = nil
                finalizeDrag()
            }
    }

    private func panGesture(imageRect: CGRect, cropRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartViewRect == nil {
                    dragStartViewRect = cropRect
                    dragStartCropValues = app.editor.crop
                }
                guard let start = dragStartViewRect else { return }
                var rect = start
                rect.origin.x += value.translation.width
                rect.origin.y += value.translation.height
                rect = clampedOrigin(rect, in: imageRect)
                app.editor.crop = cropValues(fromViewRect: rect, imageRect: imageRect)
            }
            .onEnded { _ in
                finalizeDrag()
            }
    }

    private func resizeGesture(_ handle: Handle, imageRect: CGRect, cropRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartViewRect == nil {
                    dragStartViewRect = cropRect
                    dragStartCropValues = app.editor.crop
                }
                guard let start = dragStartViewRect else { return }
                var rect = resized(start, handle: handle, translation: value.translation)
                if let ratio = app.editor.crop.aspectRatio.fixedRatio {
                    rect = enforceAspectRatio(rect, anchor: start, handle: handle, ratio: ratio)
                }
                rect = clampedSize(rect, in: imageRect)
                app.editor.crop = cropValues(fromViewRect: rect, imageRect: imageRect)
            }
            .onEnded { _ in
                finalizeDrag()
            }
    }

    private func resized(_ start: CGRect, handle: Handle, translation: CGSize) -> CGRect {
        var rect = start
        switch handle {
        case .topLeft:
            rect.origin.x += translation.width; rect.size.width -= translation.width
            rect.origin.y += translation.height; rect.size.height -= translation.height
        case .top:
            rect.origin.y += translation.height; rect.size.height -= translation.height
        case .topRight:
            rect.size.width += translation.width
            rect.origin.y += translation.height; rect.size.height -= translation.height
        case .right:
            rect.size.width += translation.width
        case .bottomRight:
            rect.size.width += translation.width; rect.size.height += translation.height
        case .bottom:
            rect.size.height += translation.height
        case .bottomLeft:
            rect.origin.x += translation.width; rect.size.width -= translation.width
            rect.size.height += translation.height
        case .left:
            rect.origin.x += translation.width; rect.size.width -= translation.width
        }
        return rect
    }

    /// Re-derives width/height to satisfy a fixed aspect ratio, anchored at whichever
    /// corner of `anchor` the dragged handle did *not* move.
    private func enforceAspectRatio(_ rect: CGRect, anchor: CGRect, handle: Handle, ratio: CGFloat) -> CGRect {
        var width = max(rect.width, 4)
        var height = width / ratio
        if abs(rect.height - anchor.height) > abs(rect.width - anchor.width) {
            height = max(rect.height, 4)
            width = height * ratio
        }
        var origin = rect.origin
        switch handle {
        case .topLeft: origin = CGPoint(x: anchor.maxX - width, y: anchor.maxY - height)
        case .top: origin = CGPoint(x: anchor.midX - width / 2, y: anchor.maxY - height)
        case .topRight: origin = CGPoint(x: anchor.minX, y: anchor.maxY - height)
        case .right: origin = CGPoint(x: anchor.minX, y: anchor.midY - height / 2)
        case .bottomRight: origin = CGPoint(x: anchor.minX, y: anchor.minY)
        case .bottom: origin = CGPoint(x: anchor.midX - width / 2, y: anchor.minY)
        case .bottomLeft: origin = CGPoint(x: anchor.maxX - width, y: anchor.minY)
        case .left: origin = CGPoint(x: anchor.maxX - width, y: anchor.midY - height / 2)
        }
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func clampedOrigin(_ rect: CGRect, in imageRect: CGRect) -> CGRect {
        var result = rect
        result.origin.x = max(imageRect.minX, min(imageRect.maxX - result.width, result.origin.x))
        result.origin.y = max(imageRect.minY, min(imageRect.maxY - result.height, result.origin.y))
        return result
    }

    private func clampedSize(_ rect: CGRect, in imageRect: CGRect) -> CGRect {
        var result = rect
        let minSize: CGFloat = 24
        result.size.width = max(minSize, min(result.width, imageRect.width))
        result.size.height = max(minSize, min(result.height, imageRect.height))
        result.origin.x = max(imageRect.minX, min(imageRect.maxX - result.width, result.origin.x))
        result.origin.y = max(imageRect.minY, min(imageRect.maxY - result.height, result.origin.y))
        return result
    }

    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    // MARK: - Normalized <-> view-space mapping

    private func fittedImageRect(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let containerAspect = containerSize.width / containerSize.height
        let imageAspect = imageSize.width / imageSize.height
        var size = containerSize
        if imageAspect > containerAspect {
            size.height = containerSize.width / imageAspect
        } else {
            size.width = containerSize.height * imageAspect
        }
        let origin = CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    /// Maps the stored (bottom-up, CoreImage-style) normalized crop rect to SwiftUI's
    /// top-down view coordinates within `imageRect`.
    private func viewCropRect(in imageRect: CGRect) -> CGRect {
        let crop = app.editor.crop
        let topFraction = 1 - crop.normalizedY - crop.normalizedHeight
        return CGRect(
            x: imageRect.minX + crop.normalizedX * imageRect.width,
            y: imageRect.minY + topFraction * imageRect.height,
            width: crop.normalizedWidth * imageRect.width,
            height: crop.normalizedHeight * imageRect.height
        )
    }

    private func cropValues(fromViewRect viewRect: CGRect, imageRect: CGRect) -> CropValues {
        var crop = app.editor.crop
        guard imageRect.width > 0, imageRect.height > 0 else { return crop }
        let normalizedX = (viewRect.minX - imageRect.minX) / imageRect.width
        let normalizedWidth = viewRect.width / imageRect.width
        let topFraction = (viewRect.minY - imageRect.minY) / imageRect.height
        let normalizedHeight = viewRect.height / imageRect.height
        let normalizedY = 1 - topFraction - normalizedHeight
        crop.normalizedX = max(0, min(1, normalizedX))
        crop.normalizedY = max(0, min(1, normalizedY))
        crop.normalizedWidth = max(0.02, min(1, normalizedWidth))
        crop.normalizedHeight = max(0.02, min(1, normalizedHeight))
        return crop
    }

    @ViewBuilder
    private func dimmingOverlay(imageRect: CGRect, cropRect: CGRect) -> some View {
        Path { path in
            path.addRect(imageRect)
            path.addRect(cropRect)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        .contentShape(Rectangle())
        .gesture(newSelectionGesture(imageRect: imageRect))
    }
}

/// Lightweight rule-of-thirds / golden-ratio / center-cross guide grid, drawn inside the
/// crop rectangle's current frame.
private struct GridGuide: Shape {
    var kind: CropGuideOverlay

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .none:
            break
        case .thirds:
            addGrid(&path, in: rect, fractions: [1.0 / 3, 2.0 / 3])
        case .goldenRatio:
            addGrid(&path, in: rect, fractions: [0.382, 0.618])
        case .centerCross:
            addGrid(&path, in: rect, fractions: [0.5])
        }
        return path
    }

    private func addGrid(_ path: inout Path, in rect: CGRect, fractions: [CGFloat]) {
        for fraction in fractions {
            let x = rect.minX + rect.width * fraction
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * fraction
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
    }
}
