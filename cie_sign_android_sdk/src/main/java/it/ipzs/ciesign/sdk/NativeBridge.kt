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
        signatureImageHeight: Int,
        useAutoSignature: Boolean,
        signerNameOverride: String?
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
        useAutoSignature: Boolean,
        signerNameOverride: String?,
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

    /**
     * Extract signature fields from a PDF document.
     * Returns an array of maps with keys: name, pageIndex, left, bottom, width, height, isSigned
     */
    @JvmStatic
    external fun extractSignatureFields(pdfBytes: ByteArray): Array<Map<String, Any>>
}
