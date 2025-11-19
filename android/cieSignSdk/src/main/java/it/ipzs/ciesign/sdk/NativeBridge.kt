package it.ipzs.ciesign.sdk

internal object NativeBridge {

    init {
        System.loadLibrary("ciesign_mobile")
    }

    @JvmStatic
    external fun mockSignPdf(
        pdfBytes: ByteArray,
        outputPath: String?,
        pageIndex: Int,
        left: Float,
        bottom: Float,
        width: Float,
        height: Float,
        reason: String?,
        location: String?,
        name: String?,
        fieldIds: Array<String>?,
        signatureImage: ByteArray?,
        signatureImageWidth: Int,
        signatureImageHeight: Int
    ): ByteArray

    @JvmStatic
    external fun signPdfWithNfc(
        pdfBytes: ByteArray,
        pin: String,
        pageIndex: Int,
        left: Float,
        bottom: Float,
        width: Float,
        height: Float,
        reason: String?,
        location: String?,
        name: String?,
        fieldIds: Array<String>?,
        signatureImage: ByteArray?,
        signatureImageWidth: Int,
        signatureImageHeight: Int,
        isoDep: android.nfc.tech.IsoDep,
        atr: ByteArray,
        outputPath: String?
    ): ByteArray

    @JvmStatic
    external fun verifyPinWithNfc(
        pin: String,
        isoDep: android.nfc.tech.IsoDep,
        atr: ByteArray
    ): Boolean
}
