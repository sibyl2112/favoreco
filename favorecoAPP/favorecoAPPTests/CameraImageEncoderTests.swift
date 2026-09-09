import UIKit
import XCTest
@testable import favoreco

final class CameraImageEncoderTests: XCTestCase {
    @MainActor
    func testJPEGEncodingReturnsReadableImageData() async {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 32)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 48, height: 32))
        }

        let data = await CameraImageEncoder.jpegData(
            from: image,
            compressionQuality: 0.8
        )

        XCTAssertNotNil(data)
        XCTAssertNotNil(data.flatMap(UIImage.init(data:)))
    }
}
