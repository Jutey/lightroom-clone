import XCTest
@testable import DarkroomLite

final class DarkroomLiteTests: XCTestCase {
    func testExportOptionsDefaults() {
        let options = ExportOptions()
        XCTAssertEqual(options.format, .jpeg)
        XCTAssertEqual(options.jpegQuality, 0.9, accuracy: 0.0001)
        XCTAssertFalse(options.resizeLongEdge)
        XCTAssertEqual(options.longEdgePixels, 2048)
        XCTAssertEqual(options.filenameSuffix, "_edited")
        XCTAssertTrue(options.addSuffixToFilename)
    }

    func testKeyComboDisplayString() {
        let combo = KeyCombo(key: "z", shift: true, command: true)
        XCTAssertEqual(combo.displayString, "⇧⌘Z")
    }

    func testKeyComboEmptyDisplaysPlaceholder() {
        XCTAssertEqual(KeyCombo(key: "").displayString, "—")
    }

    func testCropValuesIdentity() {
        XCTAssertTrue(CropValues.identity.isIdentity)
    }
}
