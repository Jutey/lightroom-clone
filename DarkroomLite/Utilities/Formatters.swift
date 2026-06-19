import Foundation

enum Formatters {
    static let captureDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let fileSize: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static func megapixels(width: Int, height: Int) -> String {
        guard width > 0, height > 0 else { return "—" }
        let mp = Double(width * height) / 1_000_000
        return String(format: "%.1f MP", mp)
    }
}
