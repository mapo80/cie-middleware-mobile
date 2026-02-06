import XCTest

final class CieSignBridgeTests: XCTestCase {
    func testMockBridgeProducesPdf() throws {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "sample", withExtension: "pdf") else {
            XCTFail("sample.pdf not found")
            return
        }
        let data = try Data(contentsOf: url)
        let bridge = CieSignMobileBridge(mockTransportWithLogger: { message in
            NSLog("[BridgeTest] %@", message)
        })
        let params = CieSignPdfParameters()
        params.pageIndex = 0
        params.left = 72
        params.bottom = 72
        params.width = 160
        params.height = 50
        params.reason = "Test Mock"
        params.name = "Unit Test"

        let signed = try bridge.sign(pdf: data, pin: "1234", appearance: params)
        XCTAssertTrue(String(decoding: signed.prefix(4), as: UTF8.self).hasPrefix("%PDF"), "Signed buffer must be a PDF")
        XCTAssertTrue(String(decoding: signed, as: UTF8.self).contains("/Type/Sig"), "Signature dictionary missing")

        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let outputURL = docs.appendingPathComponent("mock_signed_ios_bridge.pdf")
        try signed.write(to: outputURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }
}
