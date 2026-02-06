import Foundation
import Combine

@MainActor
final class SigningViewModel: ObservableObject {
    @Published var status: String = "Pronto alla firma."
    @Published var isBusy: Bool = false

    private let workerQueue = DispatchQueue(label: "it.ipzs.ciesign.ios.worker")

    func signSamplePdf(pin: String = "1234") {
        guard !isBusy else { return }
        guard let sampleUrl = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
              let pdfData = try? Data(contentsOf: sampleUrl) else {
            status = "Impossibile caricare sample.pdf"
            return
        }
        status = "Avvicina la CIE al dispositivo..."
        isBusy = true

        workerQueue.async { [weak self] in
            autoreleasepool {
                let bridge = CieSignMobileBridge(mockTransportWithLogger: { message in
                    NSLog("[CieSign] %@", message)
                })
                let params = CieSignPdfParameters()
                params.pageIndex = 0
                params.left = 72
                params.bottom = 72
                params.width = 170
                params.height = 48
                params.reason = "Firma con CIE"
                params.name = "Utente Demo"
                params.location = ""

                do {
                    let signed = try bridge.sign(pdf: pdfData, pin: pin, appearance: params)
                    DispatchQueue.main.async {
                        self?.status = "Documento firmato: \(signed.count) byte"
                        self?.isBusy = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.status = "Errore: \(error.localizedDescription)"
                        self?.isBusy = false
                    }
                }
            }
        }
    }
}
