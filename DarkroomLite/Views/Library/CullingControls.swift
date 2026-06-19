import SwiftUI

/// Compact 5-star rating control. Click a star to set the rating; clicking the
/// already-set top star clears it back to 0, mirroring Lightroom's behavior.
struct RatingControl: View {
    var rating: Int
    var size: CGFloat = 11
    var onSet: (Int) -> Void

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= rating ? .yellow : .secondary)
                    .onTapGesture {
                        onSet(i == rating ? 0 : i)
                    }
            }
        }
    }
}

struct FlagBadge: View {
    var flag: PickFlag

    var body: some View {
        switch flag {
        case .none:
            EmptyView()
        case .picked:
            Image(systemName: "flag.fill")
                .foregroundStyle(.green)
        case .rejected:
            Image(systemName: "flag.slash.fill")
                .foregroundStyle(.red)
        }
    }
}

struct ColorLabelDot: View {
    var label: ColorLabelTag
    var size: CGFloat = 8

    var color: Color? {
        switch label {
        case .none: return nil
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }

    var body: some View {
        if let color {
            Circle().fill(color).frame(width: size, height: size)
        }
    }
}

/// Overlay strip shown at the bottom of grid cells and filmstrip thumbnails: rating,
/// pick/reject flag, and color label, all at a glance.
struct PhotoBadgeOverlay: View {
    let photo: Photo
    var onSetRating: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            RatingControl(rating: photo.rating, onSet: onSetRating)
            Spacer()
            ColorLabelDot(label: photo.colorLabel)
            FlagBadge(flag: photo.flag)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55))
    }
}
