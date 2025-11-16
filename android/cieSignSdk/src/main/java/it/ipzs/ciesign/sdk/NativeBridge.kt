package it.ipzs.ciesign.sdk

internal object NativeBridge {

    init {
        System.loadLibrary("ciesign_mobile")
    }

    @JvmStatic
    external fun mockSignPdf(pdfBytes: ByteArray, outputPath: String?): ByteArray
}
