import SwiftUI

/// Interactive overlay for adding/editing local adjustment masks (radial/linear/brush) on
/// top of the loupe preview. Mirrors the crop tool's "every drag commits immediately, ⌘Z to
/// undo" model — there's no separate Confirm step, so `EditorViewModel.enterMasksTool()` /
/// `exitMasksTool()` are no-ops. New masks are added via the control bar at default geometry
/// (centered ellipse / horizontal line) rather than drawn from an empty drag, since accurately
/// replicating crop's "draw new box" gesture for a rotatable ellipse isn't worth the risk this
/// can't be interactively tested against in this environment.
struct MaskToolView: View {
    @Environment(AppController.self) private var app

    private enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }
    private enum LinearHandle {
        case start, end
    }

    @State private var dragStartViewRect: CGRect?
    @State private var dragStartMask: LocalAdjustmentMask?
    @State private var dragStartPoint: CGPoint?
    @State private var strokeInProgressIndex: Int?
    @State private var lastStrokePoint: BrushPoint?
    @State private var isErasing: Bool = false

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(containerSize: geo.size, imageSize: app.editor.previewImage?.size ?? geo.size)

            ZStack(alignment: .topLeading) {
                ForEach(app.editor.edit.localAdjustments) { mask in
                    shapeOutline(mask, imageRect: imageRect)
                }

                if let mask = selectedMask {
                    interactiveOverlay(mask, imageRect: imageRect)
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

    private var selectedMask: LocalAdjustmentMask? {
        guard let id = app.editor.selectedMaskID else { return nil }
        return app.editor.edit.localAdjustments.first(where: { $0.id == id })
    }

    // MARK: - Non-interactive outlines (drawn for every mask, selected or not)

    @ViewBuilder
    private func shapeOutline(_ mask: LocalAdjustmentMask, imageRect: CGRect) -> some View {
        let isSelected = mask.id == app.editor.selectedMaskID
        let strokeColor = isSelected ? Color.white : Color.white.opacity(0.35)

        switch mask.kind {
        case .radial:
            let rect = boundingRect(for: mask, imageRect: imageRect)
            Ellipse()
                .strokeBorder(strokeColor, lineWidth: isSelected ? 1.5 : 1)
                .frame(width: rect.width, height: rect.height)
                .rotationEffect(.degrees(-mask.rotation))
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        case .linear:
            let start = linearHandlePoint(.start, mask: mask, imageRect: imageRect)
            let end = linearHandlePoint(.end, mask: mask, imageRect: imageRect)
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(strokeColor, lineWidth: isSelected ? 1.5 : 1)
            .allowsHitTesting(false)
        case .brush:
            ForEach(Array(mask.strokes.enumerated()), id: \.offset) { _, stroke in
                strokePath(stroke, imageRect: imageRect)
                    .stroke(
                        stroke.isErase ? Color.red.opacity(0.5) : strokeColor.opacity(0.6),
                        style: StrokeStyle(lineWidth: brushLineWidth(mask, imageRect: imageRect), lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private func strokePath(_ stroke: BrushStroke, imageRect: CGRect) -> Path {
        var path = Path()
        guard let first = stroke.points.first else { return path }
        path.move(to: viewPoint(first, imageRect: imageRect))
        for point in stroke.points.dropFirst() {
            path.addLine(to: viewPoint(point, imageRect: imageRect))
        }
        return path
    }

    private func brushLineWidth(_ mask: LocalAdjustmentMask, imageRect: CGRect) -> CGFloat {
        CGFloat(mask.brushSize / 100) * min(imageRect.width, imageRect.height)
    }

    // MARK: - Interactive overlay for the selected mask

    @ViewBuilder
    private func interactiveOverlay(_ mask: LocalAdjustmentMask, imageRect: CGRect) -> some View {
        switch mask.kind {
        case .radial:
            let rect = boundingRect(for: mask, imageRect: imageRect)
            ZStack {
                Ellipse()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .gesture(radialPanGesture(imageRect: imageRect, boundingRect: rect))

                ForEach(Handle.allCases, id: \.self) { handle in
                    let point = position(for: handle, in: rect)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(radius: 1)
                        .position(point)
                        .gesture(radialResizeGesture(handle, imageRect: imageRect, boundingRect: rect))
                }
            }
        case .linear:
            let start = linearHandlePoint(.start, mask: mask, imageRect: imageRect)
            let end = linearHandlePoint(.end, mask: mask, imageRect: imageRect)
            ZStack {
                handleCircle(at: start).gesture(linearHandleGesture(.start, imageRect: imageRect, startPoint: start))
                handleCircle(at: end).gesture(linearHandleGesture(.end, imageRect: imageRect, startPoint: end))
            }
        case .brush:
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .gesture(brushGesture(imageRect: imageRect))
        }
    }

    private func handleCircle(at point: CGPoint) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 12, height: 12)
            .shadow(radius: 1)
            .position(point)
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

    // MARK: - Radial gestures

    private func radialPanGesture(imageRect: CGRect, boundingRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartViewRect == nil {
                    dragStartViewRect = boundingRect
                    dragStartMask = selectedMask
                }
                guard let start = dragStartViewRect else { return }
                var rect = start
                rect.origin.x += value.translation.width
                rect.origin.y += value.translation.height
                updateSelectedMask { mask in applyBoundingRect(rect, imageRect: imageRect, to: &mask) }
            }
            .onEnded { _ in finalizeMaskDrag(actionName: "Move Mask") }
    }

    private func radialResizeGesture(_ handle: Handle, imageRect: CGRect, boundingRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartViewRect == nil {
                    dragStartViewRect = boundingRect
                    dragStartMask = selectedMask
                }
                guard let start = dragStartViewRect else { return }
                var rect = resized(start, handle: handle, translation: value.translation)
                rect = clampedSize(rect, in: imageRect)
                updateSelectedMask { mask in applyBoundingRect(rect, imageRect: imageRect, to: &mask) }
            }
            .onEnded { _ in finalizeMaskDrag(actionName: "Resize Mask") }
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

    private func clampedSize(_ rect: CGRect, in imageRect: CGRect) -> CGRect {
        var result = rect
        let minSize: CGFloat = 16
        result.size.width = max(minSize, min(result.width, imageRect.width * 2))
        result.size.height = max(minSize, min(result.height, imageRect.height * 2))
        return result
    }

    private func boundingRect(for mask: LocalAdjustmentMask, imageRect: CGRect) -> CGRect {
        let centerXView = imageRect.minX + mask.centerX * imageRect.width
        let centerYView = imageRect.minY + (1 - mask.centerY) * imageRect.height
        let rxView = mask.radiusX * imageRect.width
        let ryView = mask.radiusY * imageRect.height
        return CGRect(x: centerXView - rxView, y: centerYView - ryView, width: rxView * 2, height: ryView * 2)
    }

    private func applyBoundingRect(_ rect: CGRect, imageRect: CGRect, to mask: inout LocalAdjustmentMask) {
        guard imageRect.width > 0, imageRect.height > 0 else { return }
        let centerX = (rect.midX - imageRect.minX) / imageRect.width
        let topFraction = (rect.midY - imageRect.minY) / imageRect.height
        mask.centerX = max(0, min(1, centerX))
        mask.centerY = max(0, min(1, 1 - topFraction))
        mask.radiusX = max(0.01, (rect.width / 2) / imageRect.width)
        mask.radiusY = max(0.01, (rect.height / 2) / imageRect.height)
    }

    // MARK: - Linear gestures

    private func linearHandlePoint(_ which: LinearHandle, mask: LocalAdjustmentMask, imageRect: CGRect) -> CGPoint {
        let (x, y): (Double, Double) = which == .start ? (mask.startX, mask.startY) : (mask.endX, mask.endY)
        return CGPoint(x: imageRect.minX + x * imageRect.width, y: imageRect.minY + (1 - y) * imageRect.height)
    }

    private func linearHandleGesture(_ which: LinearHandle, imageRect: CGRect, startPoint: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartPoint == nil {
                    dragStartPoint = startPoint
                    dragStartMask = selectedMask
                }
                guard let start = dragStartPoint, imageRect.width > 0, imageRect.height > 0 else { return }
                let newPoint = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                let normalizedX = max(0, min(1, (newPoint.x - imageRect.minX) / imageRect.width))
                let normalizedY = max(0, min(1, 1 - (newPoint.y - imageRect.minY) / imageRect.height))
                updateSelectedMask { mask in
                    if which == .start {
                        mask.startX = normalizedX; mask.startY = normalizedY
                    } else {
                        mask.endX = normalizedX; mask.endY = normalizedY
                    }
                }
            }
            .onEnded { _ in
                dragStartPoint = nil
                finalizeMaskDrag(actionName: "Move Gradient")
            }
    }

    // MARK: - Brush gesture

    private func brushGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard imageRect.width > 0, imageRect.height > 0 else { return }
                let point = value.location
                let normalizedX = max(0, min(1, (point.x - imageRect.minX) / imageRect.width))
                let normalizedY = max(0, min(1, 1 - (point.y - imageRect.minY) / imageRect.height))
                let newPoint = BrushPoint(x: normalizedX, y: normalizedY)

                if strokeInProgressIndex == nil {
                    dragStartMask = selectedMask
                    guard let id = app.editor.selectedMaskID else { return }
                    updateSelectedMask { mask in mask.strokes.append(BrushStroke(points: [newPoint], isErase: isErasing)) }
                    strokeInProgressIndex = app.editor.edit.localAdjustments.first(where: { $0.id == id }).map { $0.strokes.count - 1 }
                    lastStrokePoint = newPoint
                    return
                }

                if let last = lastStrokePoint {
                    let dx = last.x - newPoint.x, dy = last.y - newPoint.y
                    guard (dx * dx + dy * dy) > 0.0001 else { return }
                }
                lastStrokePoint = newPoint
                guard let index = strokeInProgressIndex else { return }
                updateSelectedMask { mask in
                    guard mask.strokes.indices.contains(index) else { return }
                    mask.strokes[index].points.append(newPoint)
                }
            }
            .onEnded { _ in
                if let old = dragStartMask {
                    finalizeMaskDrag(actionName: isErasing ? "Erase Mask" : "Paint Mask", old: old)
                }
                strokeInProgressIndex = nil
                lastStrokePoint = nil
            }
    }

    // MARK: - Shared helpers

    private func updateSelectedMask(_ transform: (inout LocalAdjustmentMask) -> Void) {
        guard let id = app.editor.selectedMaskID,
              let index = app.editor.edit.localAdjustments.firstIndex(where: { $0.id == id }) else { return }
        transform(&app.editor.edit.localAdjustments[index])
        app.editor.scheduleRenderAndSave()
    }

    private func finalizeMaskDrag(actionName: String) {
        if let old = dragStartMask {
            finalizeMaskDrag(actionName: actionName, old: old)
        }
        dragStartMask = nil
        dragStartViewRect = nil
    }

    private func finalizeMaskDrag(actionName: String, old: LocalAdjustmentMask) {
        guard var oldEdit = Optional(app.editor.edit), let current = selectedMask, old != current else { return }
        guard let index = oldEdit.localAdjustments.firstIndex(where: { $0.id == old.id }) else { return }
        oldEdit.localAdjustments[index] = old
        app.editor.registerUndo(actionName: actionName, oldEdit: oldEdit, oldCrop: app.editor.crop, oldPerspective: app.editor.perspective)
        app.editor.scheduleRenderAndSave()
    }

    private func viewPoint(_ point: BrushPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(x: imageRect.minX + point.x * imageRect.width, y: imageRect.minY + (1 - point.y) * imageRect.height)
    }

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

    // MARK: - Control bar

    private var controlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Menu {
                    Button("Radial Mask") { addMask(.radial) }
                    Button("Linear Mask") { addMask(.linear) }
                    Button("Brush Mask") { addMask(.brush) }
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if let mask = selectedMask {
                    Toggle("Invert", isOn: app.editor.maskBoolBinding(mask.id, \.isInverted, actionName: "Invert Mask"))
                        .toggleStyle(.button)

                    if mask.kind == .radial {
                        compactSlider("Feather", value: app.editor.maskBinding(mask.id, \.feather), range: 0...100)
                        compactSlider("Rotation", value: app.editor.maskBinding(mask.id, \.rotation), range: -180...180)
                    }

                    if mask.kind == .brush {
                        Picker("", selection: $isErasing) {
                            Text("Paint").tag(false)
                            Text("Erase").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        compactSlider("Size", value: app.editor.maskBinding(mask.id, \.brushSize), range: 1...50)
                        compactSlider("Feather", value: app.editor.maskBinding(mask.id, \.brushFeather), range: 0...100)
                    }

                    Button(role: .destructive) { deleteSelectedMask() } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)

            Text(instructionText)
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

    private func compactSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption)
            Slider(
                value: value, in: range,
                onEditingChanged: { editing in
                    if editing {
                        dragStartMask = selectedMask
                    } else if let old = dragStartMask {
                        finalizeMaskDrag(actionName: title, old: old)
                        dragStartMask = nil
                    }
                }
            )
            .frame(width: 90)
        }
    }

    private var instructionText: String {
        guard let mask = selectedMask else {
            return "Use Add to place a radial, linear, or brush mask."
        }
        switch mask.kind {
        case .radial: return "Drag inside to move, handles to resize. Adjust sliders in the panel. ⌘Z to undo."
        case .linear: return "Drag either end to reposition the gradient. Adjust sliders in the panel. ⌘Z to undo."
        case .brush: return "Drag to paint. Switch to Erase to remove. Adjust sliders in the panel. ⌘Z to undo."
        }
    }

    private func addMask(_ kind: LocalMaskKind) {
        let id = app.editor.addMask(kind: kind)
        app.editor.selectedMaskID = id
    }

    private func deleteSelectedMask() {
        guard let id = app.editor.selectedMaskID else { return }
        app.editor.deleteMask(id: id)
        app.editor.selectedMaskID = nil
    }
}
