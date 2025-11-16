import XCTest
import Foundation

final class MockSignTests: XCTestCase {
    func testMockPdfSignature() throws {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "sample", withExtension: "pdf") else {
            XCTFail("sample.pdf not found in test bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let ok = data.withUnsafeBytes { buffer -> Bool in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }
            return cie_mock_sign_ios(base, data.count)
        }
        XCTAssertTrue(ok, "Mock PDF signing did not complete successfully")
    }
}
