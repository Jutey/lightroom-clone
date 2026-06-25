import SwiftUI

/// Interactive overlay for the spot removal / healing brush tool. Each spot is drawn as two
/// circles at its actual clone radius — a solid one at the target (the blemish being covered)
/// and a dashed one at the source (the clean area sampled from) — joined by a dotted line, the
/// same visual language Lightroom's healing tool uses. Dragging either circle moves that side
/// of the clone; mirrors `MaskToolView`'s "every drag commits immediately, ⌘Z to undo" model, so
/// `EditorViewModel.enterSpotRemovalTool()` / `exitSpotRemovalTool()` are no-ops.
struct SpotRemovalToolView: View {
    @Environment(AppController.self) private var app

    private enum Side {
        case source, target
    }

    @State private var dragStartSpot: SpotRemoval?

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(containerSize: geo.size, imageSize: app.editor.previewImage?.size ?? geo.size)

            ZStack(alignment: .topLeading) {
                ForEach(app.editor.edit.spotRemovals) { spot in
                    spotOutline(spot, imageRect: imageRect)
                }

                if let spot = selectedSpot {
                    interactiveOverlay(spot, imageRect: imageRect)
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

    private var selectedSpot: SpotRemoval? {
        guard let id = app.editor.selectedSpotID else { return nil }
        return app.editor.edit.spotRemovals.first(where: { $0.id == id })
    }

    // MARK: - Non-interactive outlines (drawn for every spot, selected or not)

    @ViewBuilder
    private func spotOutline(_ spot: SpotRemoval, imageRect: CGRect) -> some View {
        let isSelected = spot.id == app.editor.selectedSpotID
        let strokeColor = isSelected ? Color.white : Color.white.opacity(0.35)
        let radius = viewRadius(for: spot, imageRect: imageRect)
        let target = point(spot.targetX, spot.targetY, imageRect: imageRect)
        let source = point(spot.sourceX, spot.sourceY, imageRect: imageRect)

        ZStack {
            Path { path in
                path.move(to: source)
                path.addLine(to: target)
            }
            .stroke(strokeColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            Circle()
                .strokeBorder(strokeColor, lineWidth: isSelected ? 1.5 : 1)
                .frame(width: radius * 2, height: radius * 2)
                .position(target)

            Circle()
                .strokeBorder(strokeColor, style: StrokeStyle(lineWidth: isSelected ? 1.5 : 1, dash: [4, 3]))
                .frame(width: radius * 2, height: radius * 2)
                .position(source)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Interactive overlay for the selected spot

    @ViewBuilder
    private func interactiveOverlay(_ spot: SpotRemoval, imageRect: CGRect) -> some View {
        let radius = viewRadius(for: spot, imageRect: imageRect)
        let target = point(spot.targetX, spot.targetY, imageRect: imageRect)
        let source = point(spot.sourceX, spot.sourceY, imageRect: imageRect)

        ZStack {
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: max(radius * 2, 24), height: max(radius * 2, 24))
                .position(target)
                .gesture(moveGesture(.target, imageRect: imageRect))

            Circle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 10, height: 10)
                .position(source)
                .gesture(moveGesture(.source, imageRect: imageRect))
        }
    }

    // MARK: - Gestures

    private func moveGesture(_ side: Side, imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard imageRect.width > 0, imageRect.height > 0 else { return }
                if dragStartSpot == nil {
                    dragStartSpot = selectedSpot
                }
                let normalizedX = max(0, min(1, (value.location.x - imageRect.minX) / imageRect.width))
                let normalizedY = max(0, min(1, 1 - (value.location.y - imageRect.minY) / imageRect.height))
                updateSelectedSpot { spot in
                    switch side {
                    case .target:
                        spot.targetX = normalizedX
                        spot.targetY = normalizedY
                    case .source:
                        spot.sourceX = normalizedX
                        spot.sourceY = normalizedY
                    }
                }
            }
            .onEnded { _ in
                finalizeSpotDrag(actionName: "Move Spot")
            }
    }

    // MARK: - Shared helpers

    /// `x`/`y` are normalized in Core Image's bottom-up space (same convention as
    /// `LocalAdjustmentMask`'s `centerX`/`centerY`), so `y` is flipped to SwiftUI's top-down view space.
    private func point(_ x: Double, _ y: Double, imageRect: CGRect) -> CGPoint {
        CGPoint(x: imageRect.minX + x * imageRect.width, y: imageRect.minY + (1 - y) * imageRect.height)
    }

    private func viewRadius(for spot: SpotRemoval, imageRect: CGRect) -> CGFloat {
        CGFloat(spot.size / 200) * min(imageRect.width, imageRect.height)
    }

    private func updateSelectedSpot(_ transform: (inout SpotRemoval) -> Void) {
        guard let id = app.editor.selectedSpotID,
              let index = app.editor.edit.spotRemovals.firstIndex(where: { $0.id == id }) else { return }
        transform(&app.editor.edit.spotRemovals[index])
        app.editor.scheduleRenderAndSave()
    }

    private func finalizeSpotDrag(actionName: String) {
        defer { dragStartSpot = nil }
        guard let old = dragStartSpot, let current = selectedSpot, old != current else { return }
        var oldEdit = app.editor.edit
        guard let index = oldEdit.spotRemovals.firstIndex(where: { $0.id == old.id }) else { return }
        oldEdit.spotRemovals[index] = old
        app.editor.registerUndo(actionName: actionName, oldEdit: oldEdit, oldCrop: app.editor.crop, oldPerspective: app.editor.perspective)
        app.editor.scheduleRenderAndSave()
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
                Button {
                    addSpot()
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)

                if let spot = selectedSpot {
                    compactSlider("Size", value: app.editor.spotBinding(spot.id, \.size), range: 1...50)
                    compactSlider("Feather", value: app.editor.spotBinding(spot.id, \.feather), range: 0...100)

                    Button(role: .destructive) { deleteSelectedSpot() } label: {
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
            Slider(value: value, in: range)
                .frame(width: 90)
        }
    }

    private var instructionText: String {
        guard selectedSpot != nil else {
            return "Use Add to place a spot, then drag the small source handle to pick a clean area."
        }
        return "Drag the large circle to move the spot, the small handle to pick the source. ⌘Z to undo."
    }

    private func addSpot() {
        let id = app.editor.addSpot()
        app.editor.selectedSpotID = id
    }

    private func deleteSelectedSpot() {
        guard let id = app.editor.selectedSpotID else { return }
        app.editor.deleteSpot(id: id)
        app.editor.selectedSpotID = nil
    }
}
